"""
Product Service - FastAPI Application
E-commerce Product Catalog Microservice
"""

import asyncio
import logging
import os
import sys
from contextlib import asynccontextmanager
from typing import Any, Dict

import structlog
import uvicorn
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from app.core.config import get_settings
from app.core.database import get_cosmos_client, close_cosmos_client
from app.core.cache import get_redis_client, close_redis_client
from app.core.logging import setup_logging
from app.core.metrics import setup_metrics
from app.api.v1.router import api_router
from app.middleware.auth import AuthMiddleware
from app.middleware.metrics import MetricsMiddleware
from app.middleware.error_handler import ErrorHandlerMiddleware

# Setup logging
setup_logging()
logger = structlog.get_logger(__name__)

# Get settings
settings = get_settings()

# Setup OpenTelemetry
def setup_tracing():
    """Setup OpenTelemetry tracing"""
    resource = Resource.create({
        "service.name": "product-service",
        "service.version": "1.0.0",
        "service.namespace": "ecommerce",
    })
    
    trace.set_tracer_provider(TracerProvider(resource=resource))
    tracer = trace.get_tracer(__name__)
    
    # Jaeger exporter
    jaeger_exporter = JaegerExporter(
        agent_host_name=settings.jaeger_host,
        agent_port=settings.jaeger_port,
    )
    
    span_processor = BatchSpanProcessor(jaeger_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)
    
    return tracer

# Setup metrics
setup_metrics()

# Setup tracing
tracer = setup_tracing()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    logger.info("Starting Product Service...")
    
    # Initialize database connections
    try:
        cosmos_client = await get_cosmos_client()
        redis_client = await get_redis_client()
        
        logger.info("Database connections established")
        
        yield
        
    except Exception as e:
        logger.error(f"Failed to initialize database connections: {e}")
        sys.exit(1)
    finally:
        # Cleanup
        logger.info("Shutting down Product Service...")
        await close_cosmos_client()
        await close_redis_client()
        logger.info("Product Service shutdown complete")

# Create FastAPI application
app = FastAPI(
    title="Product Service API",
    description="E-commerce Product Catalog Microservice",
    version="1.0.0",
    docs_url="/docs" if settings.environment == "development" else None,
    redoc_url="/redoc" if settings.environment == "development" else None,
    openapi_url="/openapi.json" if settings.environment == "development" else None,
    lifespan=lifespan,
)

# ===============================================================================
# MIDDLEWARE SETUP
# ===============================================================================

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Gzip compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Custom middleware
app.add_middleware(ErrorHandlerMiddleware)
app.add_middleware(MetricsMiddleware)
app.add_middleware(AuthMiddleware)

# ===============================================================================
# INSTRUMENTATION
# ===============================================================================

# FastAPI instrumentation
FastAPIInstrumentor.instrument_app(app)

# HTTP client instrumentation
HTTPXClientInstrumentor().instrument()

# Redis instrumentation
RedisInstrumentor().instrument()

# ===============================================================================
# ROUTES
# ===============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "product-service", "version": "1.0.0"}

@app.get("/health/ready")
async def readiness_check():
    """Readiness check endpoint"""
    try:
        # Check database connectivity
        cosmos_client = await get_cosmos_client()
        redis_client = await get_redis_client()
        
        # Simple connectivity tests
        await redis_client.ping()
        
        return {"status": "ready", "checks": {"cosmos": "ok", "redis": "ok"}}
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": str(e)}
        )

@app.get("/health/live")
async def liveness_check():
    """Liveness check endpoint"""
    return {"status": "alive", "service": "product-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

# ===============================================================================
# ERROR HANDLERS
# ===============================================================================

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "An unexpected error occurred",
            "request_id": getattr(request.state, "request_id", None),
        }
    )

# ===============================================================================
# STARTUP EVENTS
# ===============================================================================

@app.on_event("startup")
async def startup_event():
    """Application startup event"""
    logger.info("Product Service startup complete")

@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event"""
    logger.info("Product Service shutdown initiated")

# ===============================================================================
# MAIN ENTRY POINT
# ===============================================================================

if __name__ == "__main__":
    # Development server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "3003")),
        reload=settings.environment == "development",
        log_level="info",
        access_log=True,
    )
