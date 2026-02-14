# GraphQL API Unit Test Cases

## Test File

`GraphQLTests.swift`

## Test Purpose

This module tests the GraphQL API implementation for SwiftCMS, covering query operations, mutations, authentication, authorization, error handling, and performance characteristics. Tests use XCTVapor for HTTP testing and FluentSQLiteDriver for database operations.

## Test Cases Overview

| Case ID | Feature Description | Test Type |
| ------- | ------------------- | ------------- |
| GQL-01 | Health check query | Positive Test |
| GQL-02 | Query content entries with pagination | Positive Test |
| GQL-03 | Query content entries with filters | Positive Test |
| GQL-04 | Query single content entry by ID | Positive Test |
| GQL-05 | Query content type definitions | Positive Test |
| GQL-06 | Me query (authenticated) | Positive Test |
| GQL-07 | Create content entry mutation | Positive Test |
| GQL-08 | Update content entry mutation | Positive Test |
| GQL-09 | Delete content entry mutation | Positive Test |
| GQL-10 | Publish content entry mutation | Positive Test |
| GQL-11 | Unpublish content entry mutation | Positive Test |
| GQL-12 | Create content type definition mutation | Positive Test |
| GQL-13 | Unauthenticated query access | Positive Test |
| GQL-14 | Authenticated mutation requirement | Error Test |
| GQL-15 | Role-based access control | Error Test |
| GQL-16 | Token verification | Positive Test |
| GQL-17 | Invalid GraphQL query syntax | Error Test |
| GQL-18 | Missing required fields in mutation | Error Test |
| GQL-19 | Permission denied for non-admin | Error Test |
| GQL-20 | Content entry not found error | Error Test |
| GQL-21 | Content type validation errors | Error Test |
| GQL-22 | Large dataset pagination | Performance Test |
| GQL-23 | Complex nested queries | Performance Test |
| GQL-24 | Concurrent request handling | Performance Test |

## Detailed Test Steps

### GQL-01: Health Check Query

**Test Purpose**: Verify the GraphQL health check query returns system status

**Test Data Preparation**:
- Initialize test application with SQLite database
- Run migrations

**Test Steps**:
1. Send GraphQL query: `{ health { status version } }`
2. Verify response structure
3. Check status is "ok"
4. Verify version is present

**Expected Results**:
- Response contains `health` object
- `status` field equals "ok"
- `version` field is a non-empty string

### GQL-02: Query Content Entries with Pagination

**Test Purpose**: Verify content entries can be queried with pagination

**Test Data Preparation**:
- Create 25 content entries of type "article"
- Use SQLite in-memory database

**Test Steps**:
1. Send GraphQL query with pagination parameters:
   ```graphql
   query {
     contentEntries(contentType: "article", page: 1, perPage: 10) {
       data {
         id
         contentType
         status
       }
       pageInfo {
         page
         perPage
         total
         totalPages
         hasNextPage
         hasPreviousPage
       }
     }
   }
   ```
2. Verify response structure
3. Check pagination metadata

**Expected Results**:
- Response contains array of 10 entries
- `pageInfo.total` equals 25
- `pageInfo.totalPages` equals 3
- `pageInfo.hasNextPage` is true
- `pageInfo.hasPreviousPage` is false

### GQL-03: Query Content Entries with Filters

**Test Purpose**: Verify content entries can be filtered by status and locale

**Test Data Preparation**:
- Create draft entries (5)
- Create published entries (3)
- Create entries with different locales

**Test Steps**:
1. Send query with status filter:
   ```graphql
   query {
     contentEntries(contentType: "article", filter: { status: "published" }) {
       data { id status }
     }
   }
   ```
2. Send query with locale filter
3. Verify filters are applied correctly

**Expected Results**:
- Status filter returns only published entries
- Locale filter returns only matching locale entries
- Filters can be combined

### GQL-04: Query Single Content Entry by ID

**Test Purpose**: Verify a single content entry can be retrieved by ID

**Test Data Preparation**:
- Create a content entry with known ID

**Test Steps**:
1. Send query with entry ID:
   ```graphql
   query {
     contentEntry(id: "<uuid>") {
       id
       contentType
       data
       status
       createdAt
       updatedAt
     }
   }
   ```
2. Verify entry data matches

**Expected Results**:
- Entry with matching ID is returned
- All fields are populated correctly
- null response if ID doesn't exist

### GQL-05: Query Content Type Definitions

**Test Purpose**: Verify content type definitions can be queried

**Test Data Preparation**:
- Create multiple content type definitions (article, page, author)

**Test Steps**:
1. Send query:
   ```graphql
   query {
     contentTypeDefinitions {
       id
       name
       slug
       displayName
       description
       kind
       jsonSchema
     }
   }
   ```
2. Verify all definitions are returned

**Expected Results**:
- All content type definitions are returned
- Each includes schema information
- Definitions match created types

### GQL-06: Me Query (Authenticated)

**Test Purpose**: Verify authenticated user can query their own information

**Test Data Preparation**:
- Create test user with roles
- Generate valid JWT token

**Test Steps**:
1. Send query with Authorization header:
   ```graphql
   query {
     me {
       id
       email
       displayName
       roles
     }
   }
   ```
2. Verify user information is returned

**Expected Results**:
- User information matches authenticated user
- Roles array contains user roles
- Returns null without authentication

### GQL-07: Create Content Entry Mutation

**Test Purpose**: Verify content entries can be created via mutation

**Test Data Preparation**:
- Create a content type definition
- Authenticate as user with create permission

**Test Steps**:
1. Send mutation:
   ```graphql
   mutation {
     createContentEntry(input: {
       contentType: "article"
       data: { title: "Test", content: "Content" }
       status: "draft"
     }) {
       id
       contentType
       data
       status
     }
   }
   ```
2. Verify entry is created in database
3. Check response contains created entry

**Expected Results**:
- Entry is created successfully
- Response includes generated ID
- All fields match input
- Database contains the entry

### GQL-08: Update Content Entry Mutation

**Test Purpose**: Verify content entries can be updated via mutation

**Test Data Preparation**:
- Create an existing content entry
- Authenticate with update permission

**Test Steps**:
1. Send mutation with entry ID and updated data:
   ```graphql
   mutation {
     updateContentEntry(input: {
       id: "<uuid>"
       data: { title: "Updated Title" }
     }) {
       id
       data
       updatedAt
     }
   }
   ```
2. Verify entry is updated
3. Check updatedAt timestamp changed

**Expected Results**:
- Entry data is updated
- Response contains updated fields
- updatedAt timestamp is newer
- Original data is preserved for non-updated fields

### GQL-09: Delete Content Entry Mutation

**TestPurpose**: Verify content entries can be deleted via mutation

**Test Data Preparation**:
- Create a content entry to delete
- Authenticate with delete permission

**Test Steps**:
1. Send mutation:
   ```graphql
   mutation {
     deleteContentEntry(id: "<uuid>") {
       id
       success
     }
   }
   ```
2. Verify entry is deleted from database
3. Attempt to query deleted entry

**Expected Results**:
- Mutation returns success: true
- Entry is removed from database
- Subsequent query returns null

### GQL-10: Publish Content Entry Mutation

**Test Purpose**: Verify content entries can be published

**Test Data Preparation**:
- Create a draft content entry
- Authenticate with publish permission

**Test Steps**:
1. Send mutation:
   ```graphql
   mutation {
     publishContentEntry(id: "<uuid>") {
       id
       status
       publishedAt
     }
   }
   ```
2. Verify status changed to published
3. Check publishedAt is set

**Expected Results**:
- Status changes to "published"
- publishedAt timestamp is set
- Entry is now queryable in published state

### GQL-11: Unpublish Content Entry Mutation

**Test Purpose**: Verify published entries can be unpublished

**Test Data Preparation**:
- Create a published content entry
- Authenticate with unpublish permission

**Test Steps**:
1. Send mutation:
   ```graphql
   mutation {
     unpublishContentEntry(id: "<uuid>") {
       id
       status
       publishedAt
     }
   }
   ```
2. Verify status changed back to draft

**Expected Results**:
- Status changes to "draft"
- publishedAt is cleared (null)
- Entry remains in database

### GQL-12: Create Content Type Definition Mutation (Admin Only)

**Test Purpose**: Verify content types can be created by admins

**Test Data Preparation**:
- Authenticate as admin user
- Prepare valid JSON schema

**Test Steps**:
1. Send mutation:
   ```graphql
   mutation {
     createContentType(input: {
       name: "blog"
       slug: "blog"
       description: "Blog posts"
       jsonSchema: { type: "object", properties: { title: { type: "string" } } }
     }) {
       id
       name
       slug
     }
   }
   ```
2. Verify content type is created

**Expected Results**:
- Content type is created successfully
- Schema is stored correctly
- Only admins can create (403 for non-admins)

### GQL-13: Unauthenticated Query Access

**Test Purpose**: Verify public queries work without authentication

**Test Data Preparation**:
- Do not set Authorization header

**Test Steps**:
1. Send health check query without auth
2. Send content entries query without auth
3. Verify queries succeed

**Expected Results**:
- Public queries return data
- No authentication required
- Response status is 200 OK

### GQL-14: Authenticated Mutation Requirement

**Test Purpose**: Verify mutations require authentication

**Test Data Preparation**:
- Do not authenticate request

**Test Steps**:
1. Attempt createContentEntry mutation without auth
2. Attempt updateContentEntry mutation without auth
3. Attempt deleteContentEntry mutation without auth

**Expected Results**:
- All mutations return 401 Unauthorized
- Error message indicates authentication required
- No data is modified

### GQL-15: Role-Based Access Control

**Test Purpose**: Verify users can only access permitted operations

**Test Data Preparation**:
- Create user with "editor" role (can create/edit, not delete)
- Create user with "viewer" role (read-only)

**Test Steps**:
1. Authenticate as editor, attempt delete (should fail)
2. Authenticate as viewer, attempt create (should fail)
3. Authenticate as admin, attempt all (should succeed)

**Expected Results**:
- Editor gets 403 on delete
- Viewer gets 403 on create/update/delete
- Admin can perform all operations

### GQL-16: Token Verification

**Test Purpose**: Verify JWT tokens are validated correctly

**Test Data Preparation**:
- Generate valid JWT token
- Generate expired JWT token
- Generate malformed token

**Test Steps**:
1. Send request with valid token
2. Send request with expired token
3. Send request with malformed token
4. Send request with valid token for different user

**Expected Results**:
- Valid token: Request succeeds
- Expired token: 401 Unauthorized
- Malformed token: 401 Unauthorized
- Different user token: Request succeeds as that user

### GQL-17: Invalid GraphQL Query Syntax

**Test Purpose**: Verify invalid queries are rejected with helpful errors

**Test Data Preparation**:
- Prepare malformed GraphQL queries

**Test Steps**:
1. Send query with syntax errors
2. Send query with non-existent fields
3. Send query with wrong types

**Expected Results**:
- Response includes GraphQL errors
- Error messages are descriptive
- HTTP status is 200 (GraphQL errors in body)
- Error locations point to problem

### GQL-18: Missing Required Fields in Mutation

**Test Purpose**: Verify mutations validate required input

**Test Data Preparation**:
- Prepare mutation with missing required fields

**Test Steps**:
1. Send createContentEntry without contentType
2. Send createContentEntry without data
3. Send updateContentEntry without id

**Expected Results**:
- Mutation returns validation error
- Error specifies missing fields
- No entry is created

### GQL-19: Permission Denied for Non-Admin

**Test Purpose**: Verify admin-only mutations reject non-admin users

**Test Data Preparation**:
- Authenticate as non-admin user

**Test Steps**:
1. Attempt createContentType mutation
2. Attempt updateContentType mutation
3. Attempt deleteContentType mutation

**Expected Results**:
- All mutations return 403 Forbidden
- Error indicates insufficient permissions
- No changes are made

### GQL-20: Content Entry Not Found Error

**Test Purpose**: Verify querying non-existent entries returns null/error

**Test Data Preparation**:
- Generate random UUID that doesn't exist

**Test Steps**:
1. Query contentEntry with non-existent ID
2. Attempt to update non-existent entry
3. Attempt to delete non-existent entry

**Expected Results**:
- Query returns null (not error)
- Mutations return error or null result
- Appropriate error messages

### GQL-21: Content Type Validation Errors

**Test Purpose**: Verify data is validated against content type schema

**Test Data Preparation**:
- Create content type with required fields
- Create entry with missing required field

**Test Steps**:
1. Create entry missing required field
2. Create entry with wrong data type
3. Create entry with invalid enum value

**Expected Results**:
- Mutation returns validation error
- Error specifies validation failures
- Entry is not created

### GQL-22: Large Dataset Pagination

**Test Purpose**: Verify pagination performance with large datasets

**Test Data Preparation**:
- Create 1000+ content entries
- Use SQLite for testing

**Test Steps**:
1. Query first page (page: 1, perPage: 50)
2. Query middle page (page: 10, perPage: 50)
3. Query last page (page: 20, perPage: 50)
4. Measure response times

**Expected Results**:
- All queries complete in reasonable time (<1s)
- Page metadata is accurate
- No duplicate entries across pages
- All entries are accessible

### GQL-23: Complex Nested Queries

**Test Purpose**: Verify GraphQL can handle complex nested structures

**Test Data Preparation**:
- Create entries with nested data structures
- Create related entries

**Test Steps**:
1. Send query with nested field selections
2. Send query with fragments
3. Send query with aliases
4. Send query with multiple root fields

**Expected Results**:
- Nested data is returned correctly
- Fragments work as expected
- Aliases don't conflict
- Multiple root fields execute correctly

### GQL-24: Concurrent Request Handling

**Test Purpose**: Verify GraphQL handles concurrent requests safely

**Test Data Preparation**:
- Prepare test data set

**Test Steps**:
1. Send 100 concurrent read queries
2. Send 50 concurrent create mutations
3. Send mixed concurrent operations
4. Verify no race conditions

**Expected Results**:
- All requests complete successfully
- No data corruption
- Response times are acceptable
- Database connections are managed properly

## Test Considerations

### Mock Strategy

- Use FluentSQLiteDriver for in-memory database
- Mock authentication provider for token generation
- Mock event bus to prevent side effects
- Use XCTVapor's Application.testable for HTTP testing

### Boundary Conditions

- Empty result sets
- Pagination edge cases (first page, last page, empty page)
- Maximum page size (enforce 100 limit)
- Very large JSON payloads
- Unicode and special characters in data

### Asynchronous Operations

- Use async/await for all database operations
- Test concurrent mutations
- Verify transaction isolation
- Check for race conditions in status updates

### Performance Benchmarks

- Queries should complete in <500ms for 100 results
- Mutations should complete in <1s
- Concurrent load: handle 50 simultaneous requests
- Memory usage should remain stable

### Security Considerations

- Validate all inputs against schemas
- Check authorization on all mutations
- Prevent SQL injection in filters
- Rate limit expensive queries
- Sanitize error messages (no internal info)
