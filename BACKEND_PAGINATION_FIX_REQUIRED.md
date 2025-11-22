# Backend API Issue: Comment Pagination Not Working

## 🚨 Critical Issue

The `GET /posts/{postId}/comments` endpoint is **NOT supporting pagination** and always returns only the first 10 comments, regardless of pagination parameters.

---

## Current Behavior (BROKEN)

### Test Results:
```bash
# Request 1
GET /posts/789291D6-BCD6-41D6-B174-22DB4434D2CD/comments?limit=10&offset=0
Response: Returns comments 1-10

# Request 2
GET /posts/789291D6-BCD6-41D6-B174-22DB4434D2CD/comments?limit=10&offset=10
Response: Returns THE SAME comments 1-10 (should return 11-20)

# Request 3
GET /posts/789291D6-BCD6-41D6-B174-22DB4434D2CD/comments?limit=10&offset=20
Response: Returns THE SAME comments 1-10 (should return 21-30)
```

**Result**: The `offset` parameter is being **completely ignored** by the backend.

---

## Impact

- Users can only see the first 10 comments on any post
- Posts showing "24 comments" only display 10
- Infinite loop in client when trying to load all comments
- Poor user experience compared to Instagram/Twitter/other social platforms

---

## Required Fix

Implement **offset-based pagination** for the comments endpoint.

### API Specification

**Endpoint**: `GET /posts/{postId}/comments`

**Query Parameters**:
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `limit` | integer | Optional | Number of comments to return (default: 10, max: 50) | `10` |
| `offset` | integer | Optional | Number of comments to skip (default: 0) | `0`, `10`, `20` |

**Response Format**:
```json
[
  {
    "id": "uuid",
    "postId": "uuid",
    "userId": "uuid",
    "content": "string",
    "createdAt": "ISO8601 timestamp",
    "updatedAt": "ISO8601 timestamp"
  }
]
```

---

## Implementation Guide

### Database Query (Example - PostgreSQL)

```sql
SELECT * FROM comments 
WHERE post_id = $1 
ORDER BY created_at DESC 
LIMIT $2 OFFSET $3
```

### Pseudocode (Backend Logic)

```javascript
async function getComments(postId, limit = 10, offset = 0) {
  // Validate parameters
  limit = Math.min(limit, 50); // Max 50 comments per request
  offset = Math.max(offset, 0); // Offset cannot be negative
  
  // Query database with LIMIT and OFFSET
  const comments = await db.query(
    'SELECT * FROM comments WHERE post_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
    [postId, limit, offset]
  );
  
  return comments;
}
```

---

## Testing Criteria

### Test Case 1: First Page
```bash
GET /posts/{postId}/comments?limit=10&offset=0

Expected: Returns comments 1-10 (newest first)
Verify: Check comment IDs and timestamps
```

### Test Case 2: Second Page
```bash
GET /posts/{postId}/comments?limit=10&offset=10

Expected: Returns comments 11-20
Verify: Comment IDs should be DIFFERENT from Test Case 1
```

### Test Case 3: Third Page
```bash
GET /posts/{postId}/comments?limit=10&offset=20

Expected: Returns comments 21-30
Verify: Comment IDs should be DIFFERENT from Test Case 1 and 2
```

### Test Case 4: Post with 24 Comments
Given a post with exactly 24 comments:
```bash
# Page 1
GET /posts/{postId}/comments?limit=10&offset=0
Expected: 10 comments (IDs: 1-10)

# Page 2  
GET /posts/{postId}/comments?limit=10&offset=10
Expected: 10 comments (IDs: 11-20)

# Page 3
GET /posts/{postId}/comments?limit=10&offset=20
Expected: 4 comments (IDs: 21-24)

# Page 4
GET /posts/{postId}/comments?limit=10&offset=30
Expected: 0 comments (empty array)
```

---

## Alternative: Cursor-Based Pagination (Optional Enhancement)

If you prefer cursor-based pagination instead:

**Endpoint**: `GET /posts/{postId}/comments?limit=10&cursor={timestamp}`

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | integer | Optional | Number of comments (default: 10) |
| `cursor` | string | Optional | ISO8601 timestamp of last comment from previous page |

**Response Format**:
```json
{
  "comments": [...],
  "nextCursor": "2025-11-22T12:16:35.061Z",
  "hasMore": true
}
```

---

## Priority

**🔴 HIGH PRIORITY** - This is a critical user experience issue affecting all posts with >10 comments.

---

## Test Posts for Verification

Use these test post IDs (they have >10 comments):
- `789291D6-BCD6-41D6-B174-22DB4434D2CD` (24 comments)
- `8EB48E23-6974-458A-AA06-2CF277DF2317` (24 comments)

---

## Questions?

Contact: iOS Development Team
Date Reported: 2025-11-22

---

## Additional Notes

### Also Broken: POST /posts/{postId}/comments

The comment creation endpoint is also failing:

```bash
POST /posts/{postId}/comments
Body: {"content": "Hi"}

Current Response: ERROR (returns null)
Expected: Return the created comment object
```

**This needs to be fixed as well** - users cannot add new comments.
