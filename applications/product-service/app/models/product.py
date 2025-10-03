"""
Product Models
Data models for product catalog
"""

from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Dict, List, Optional, Any
from uuid import uuid4

from pydantic import BaseModel, Field, validator, HttpUrl
from slugify import slugify


class ProductStatus(str, Enum):
    """Product status enumeration"""
    ACTIVE = "active"
    INACTIVE = "inactive"
    DRAFT = "draft"
    ARCHIVED = "archived"
    OUT_OF_STOCK = "out_of_stock"


class ProductType(str, Enum):
    """Product type enumeration"""
    PHYSICAL = "physical"
    DIGITAL = "digital"
    SERVICE = "service"
    SUBSCRIPTION = "subscription"


class ProductCondition(str, Enum):
    """Product condition enumeration"""
    NEW = "new"
    USED = "used"
    REFURBISHED = "refurbished"
    DAMAGED = "damaged"


class ProductImage(BaseModel):
    """Product image model"""
    id: str = Field(default_factory=lambda: str(uuid4()))
    url: HttpUrl
    alt_text: str = ""
    is_primary: bool = False
    sort_order: int = 0
    width: Optional[int] = None
    height: Optional[int] = None
    size_bytes: Optional[int] = None
    format: Optional[str] = None  # jpg, png, webp, etc.


class ProductVariant(BaseModel):
    """Product variant model"""
    id: str = Field(default_factory=lambda: str(uuid4()))
    sku: str
    name: str
    price: Decimal = Field(ge=0)
    compare_at_price: Optional[Decimal] = Field(None, ge=0)
    cost_price: Optional[Decimal] = Field(None, ge=0)
    inventory_quantity: int = Field(ge=0)
    weight: Optional[Decimal] = Field(None, ge=0)
    dimensions: Optional[Dict[str, Decimal]] = None  # length, width, height
    attributes: Dict[str, Any] = Field(default_factory=dict)  # size, color, etc.
    images: List[ProductImage] = Field(default_factory=list)
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    @validator('compare_at_price')
    def validate_compare_at_price(cls, v, values):
        if v is not None and 'price' in values and v <= values['price']:
            raise ValueError('Compare at price must be greater than price')
        return v


class ProductCategory(BaseModel):
    """Product category model"""
    id: str
    name: str
    slug: str
    parent_id: Optional[str] = None
    level: int = 0
    path: str = ""  # Full category path


class ProductReview(BaseModel):
    """Product review model"""
    id: str = Field(default_factory=lambda: str(uuid4()))
    user_id: str
    user_name: str
    rating: int = Field(ge=1, le=5)
    title: str
    content: str
    verified_purchase: bool = False
    helpful_votes: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class ProductSEO(BaseModel):
    """Product SEO model"""
    meta_title: Optional[str] = None
    meta_description: Optional[str] = None
    meta_keywords: List[str] = Field(default_factory=list)
    canonical_url: Optional[HttpUrl] = None
    og_title: Optional[str] = None
    og_description: Optional[str] = None
    og_image: Optional[HttpUrl] = None


class ProductShipping(BaseModel):
    """Product shipping information"""
    weight: Optional[Decimal] = Field(None, ge=0)
    dimensions: Optional[Dict[str, Decimal]] = None
    shipping_class: Optional[str] = None
    free_shipping: bool = False
    shipping_cost: Optional[Decimal] = Field(None, ge=0)
    handling_time: Optional[int] = None  # days
    origin_country: Optional[str] = None


class ProductInventory(BaseModel):
    """Product inventory model"""
    track_inventory: bool = True
    inventory_quantity: int = Field(ge=0)
    low_stock_threshold: int = Field(default=10, ge=0)
    allow_backorders: bool = False
    inventory_policy: str = "deny"  # deny, continue
    reserved_quantity: int = Field(default=0, ge=0)
    available_quantity: int = Field(ge=0)

    @validator('available_quantity', always=True)
    def calculate_available_quantity(cls, v, values):
        if 'inventory_quantity' in values and 'reserved_quantity' in values:
            return max(0, values['inventory_quantity'] - values['reserved_quantity'])
        return v


class Product(BaseModel):
    """Main product model"""
    # Core fields
    id: str = Field(default_factory=lambda: str(uuid4()))
    category_id: str  # Partition key for CosmosDB
    sku: str
    name: str = Field(min_length=1, max_length=255)
    slug: str = ""
    description: str = ""
    short_description: str = ""
    
    # Product details
    type: ProductType = ProductType.PHYSICAL
    status: ProductStatus = ProductStatus.DRAFT
    condition: ProductCondition = ProductCondition.NEW
    brand: Optional[str] = None
    manufacturer: Optional[str] = None
    model: Optional[str] = None
    
    # Pricing
    price: Decimal = Field(ge=0)
    compare_at_price: Optional[Decimal] = Field(None, ge=0)
    cost_price: Optional[Decimal] = Field(None, ge=0)
    currency: str = "USD"
    
    # Inventory
    inventory: ProductInventory = Field(default_factory=ProductInventory)
    
    # Media
    images: List[ProductImage] = Field(default_factory=list)
    videos: List[HttpUrl] = Field(default_factory=list)
    
    # Variants
    has_variants: bool = False
    variants: List[ProductVariant] = Field(default_factory=list)
    
    # Categories and tags
    categories: List[ProductCategory] = Field(default_factory=list)
    tags: List[str] = Field(default_factory=list)
    
    # Attributes
    attributes: Dict[str, Any] = Field(default_factory=dict)
    custom_fields: Dict[str, Any] = Field(default_factory=dict)
    
    # SEO
    seo: ProductSEO = Field(default_factory=ProductSEO)
    
    # Shipping
    shipping: ProductShipping = Field(default_factory=ProductShipping)
    
    # Reviews and ratings
    reviews: List[ProductReview] = Field(default_factory=list)
    average_rating: Decimal = Field(default=Decimal('0'), ge=0, le=5)
    review_count: int = Field(default=0, ge=0)
    
    # Visibility and publishing
    is_published: bool = False
    is_featured: bool = False
    is_digital: bool = False
    requires_shipping: bool = True
    
    # Dates
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    published_at: Optional[datetime] = None
    
    # Analytics
    view_count: int = Field(default=0, ge=0)
    purchase_count: int = Field(default=0, ge=0)
    
    # Document metadata for CosmosDB
    type_doc: str = Field(default="product", alias="type")
    ttl: Optional[int] = None  # Time to live in seconds
    
    class Config:
        """Pydantic configuration"""
        use_enum_values = True
        validate_assignment = True
        arbitrary_types_allowed = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: float(v),
        }

    @validator('slug', always=True)
    def generate_slug(cls, v, values):
        """Generate slug from name if not provided"""
        if not v and 'name' in values:
            return slugify(values['name'])
        return v

    @validator('compare_at_price')
    def validate_compare_at_price(cls, v, values):
        """Validate compare at price is greater than price"""
        if v is not None and 'price' in values and v <= values['price']:
            raise ValueError('Compare at price must be greater than price')
        return v

    @validator('is_digital', always=True)
    def set_digital_properties(cls, v, values):
        """Set digital product properties"""
        if 'type' in values and values['type'] == ProductType.DIGITAL:
            return True
        return v

    @validator('requires_shipping', always=True)
    def set_shipping_requirements(cls, v, values):
        """Set shipping requirements based on product type"""
        if 'type' in values and values['type'] in [ProductType.DIGITAL, ProductType.SERVICE]:
            return False
        return v

    def get_primary_image(self) -> Optional[ProductImage]:
        """Get primary product image"""
        for image in self.images:
            if image.is_primary:
                return image
        return self.images[0] if self.images else None

    def get_available_quantity(self) -> int:
        """Get available inventory quantity"""
        if not self.inventory.track_inventory:
            return 999999  # Unlimited
        return self.inventory.available_quantity

    def is_in_stock(self) -> bool:
        """Check if product is in stock"""
        if not self.inventory.track_inventory:
            return True
        return self.inventory.available_quantity > 0

    def is_low_stock(self) -> bool:
        """Check if product is low in stock"""
        if not self.inventory.track_inventory:
            return False
        return (
            self.inventory.available_quantity <= self.inventory.low_stock_threshold
            and self.inventory.available_quantity > 0
        )

    def calculate_discount_percentage(self) -> Optional[Decimal]:
        """Calculate discount percentage"""
        if self.compare_at_price and self.compare_at_price > self.price:
            discount = (self.compare_at_price - self.price) / self.compare_at_price
            return round(discount * 100, 2)
        return None

    def update_average_rating(self):
        """Update average rating based on reviews"""
        if not self.reviews:
            self.average_rating = Decimal('0')
            self.review_count = 0
            return

        total_rating = sum(review.rating for review in self.reviews)
        self.average_rating = Decimal(str(round(total_rating / len(self.reviews), 2)))
        self.review_count = len(self.reviews)


# ===============================================================================
# REQUEST/RESPONSE MODELS
# ===============================================================================

class ProductCreateRequest(BaseModel):
    """Product creation request model"""
    category_id: str
    sku: str
    name: str
    description: str = ""
    price: Decimal = Field(ge=0)
    inventory_quantity: int = Field(ge=0)
    type: ProductType = ProductType.PHYSICAL
    status: ProductStatus = ProductStatus.DRAFT


class ProductUpdateRequest(BaseModel):
    """Product update request model"""
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[Decimal] = Field(None, ge=0)
    inventory_quantity: Optional[int] = Field(None, ge=0)
    status: Optional[ProductStatus] = None
    is_published: Optional[bool] = None


class ProductSearchRequest(BaseModel):
    """Product search request model"""
    query: Optional[str] = None
    category_id: Optional[str] = None
    min_price: Optional[Decimal] = Field(None, ge=0)
    max_price: Optional[Decimal] = Field(None, ge=0)
    status: Optional[ProductStatus] = None
    is_published: Optional[bool] = None
    tags: Optional[List[str]] = None
    sort_by: str = "created_at"
    sort_order: str = "desc"
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)


class ProductResponse(BaseModel):
    """Product response model"""
    id: str
    category_id: str
    sku: str
    name: str
    slug: str
    description: str
    price: Decimal
    currency: str
    status: ProductStatus
    is_published: bool
    is_in_stock: bool
    available_quantity: int
    primary_image: Optional[ProductImage] = None
    average_rating: Decimal
    review_count: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_product(cls, product: Product) -> "ProductResponse":
        """Create response from product model"""
        return cls(
            id=product.id,
            category_id=product.category_id,
            sku=product.sku,
            name=product.name,
            slug=product.slug,
            description=product.description,
            price=product.price,
            currency=product.currency,
            status=product.status,
            is_published=product.is_published,
            is_in_stock=product.is_in_stock(),
            available_quantity=product.get_available_quantity(),
            primary_image=product.get_primary_image(),
            average_rating=product.average_rating,
            review_count=product.review_count,
            created_at=product.created_at,
            updated_at=product.updated_at,
        )
