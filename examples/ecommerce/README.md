# E-Commerce Catalog Example

Demonstrates SwiftCMS managing a product catalog with categories and relations.

## Content Types

### Categories
```json
{
  "name": "Categories",
  "slug": "categories",
  "kind": "collection",
  "jsonSchema": {
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "description": {"type": "string"},
      "image": {"type": "string", "format": "uuid"},
      "parentCategory": {"type": "string", "format": "uuid"}
    },
    "required": ["name"]
  }
}
```

### Products
```json
{
  "name": "Products",
  "slug": "products",
  "kind": "collection",
  "jsonSchema": {
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "description": {"type": "string"},
      "price": {"type": "number"},
      "sku": {"type": "string"},
      "category": {"type": "string", "format": "uuid"},
      "images": {"type": "array", "items": {"type": "string", "format": "uuid"}},
      "inStock": {"type": "boolean"},
      "variants": {"type": "array", "items": {"type": "object"}}
    },
    "required": ["name", "price", "sku"]
  }
}
```

## API Queries
```bash
# List products with category populated
curl "http://localhost:8080/api/v1/products?populate=category&status=published"

# Filter by price
curl "http://localhost:8080/api/v1/products?filter[price][lt]=50"

# Search products
curl "http://localhost:8080/api/v1/search?q=shirt&type=products"
```
