import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

// 📊 OpenTelemetry instrumentation for observability
import { WebSDK } from '@opentelemetry/sdk-web';
import { getWebAutoInstrumentations } from '@opentelemetry/auto-instrumentations-web';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

// Initialize OpenTelemetry
const sdk = new WebSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'ecommerce-frontend',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
  }),
  instrumentations: [getWebAutoInstrumentations({
    '@opentelemetry/instrumentation-document-load': {
      enabled: true,
    },
    '@opentelemetry/instrumentation-user-interaction': {
      enabled: true,
    },
    '@opentelemetry/instrumentation-fetch': {
      enabled: true,
      propagateTraceHeaderCorsUrls: [
        /^https?:\/\/api-gateway/,
        /^https?:\/\/.*\.local/,
      ],
    },
    '@opentelemetry/instrumentation-xml-http-request': {
      enabled: true,
      propagateTraceHeaderCorsUrls: [
        /^https?:\/\/api-gateway/,
        /^https?:\/\/.*\.local/,
      ],
    },
  })],
});

// Start the SDK
sdk.start();

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
