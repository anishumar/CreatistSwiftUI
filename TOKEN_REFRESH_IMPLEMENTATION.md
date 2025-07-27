# Token Refresh Implementation Guide

## Overview

This implementation provides a comprehensive solution for automatic token refresh in your SwiftUI app. It combines both **proactive** and **reactive** token refresh mechanisms to ensure seamless user experience.

## Key Components

### 1. TokenMonitor (Proactive Refresh)
- **Location**: `Creatist/DataController/NetworkManager.swift`
- **Purpose**: Monitors token expiration and refreshes tokens 5 minutes before expiry
- **Features**:
  - Background timer-based monitoring
  - Automatic restart after successful refresh
  - App lifecycle integration

### 2. Enhanced NetworkManager (Reactive Refresh)
- **Location**: `Creatist/DataController/NetworkManager.swift`
- **Purpose**: Handles 401 errors and automatically retries requests with fresh tokens
- **Features**:
  - Proactive token validation before requests
  - Automatic retry on 401 errors
  - Token expiration time storage

### 3. Token Storage & Management
- **Location**: `Creatist/DataController/KeychainHelper.swift`
- **Purpose**: Secure storage of tokens and expiration times
- **Stored Keys**:
  - `accessToken`: Current access token
  - `refreshToken`: Refresh token for getting new access tokens
  - `tokenExpirationTime`: Unix timestamp of when token expires

## How It Works

### 1. Login Flow
```swift
// When user logs in successfully:
1. Store access_token and refresh_token in Keychain
2. Store expiration time (current time + expires_in)
3. Start TokenMonitor to begin proactive monitoring
```

### 2. Proactive Refresh (TokenMonitor)
```swift
// Every time a token is received:
1. Calculate when token will expire
2. Schedule a timer to refresh 5 minutes before expiry
3. When timer fires, call refreshToken() API
4. If successful, restart monitoring with new token
5. If failed, stop monitoring (user will be logged out on next 401)
```

### 3. Reactive Refresh (NetworkManager)
```swift
// Before each API request:
1. Check if token is expired or expiring soon
2. If yes, refresh token proactively
3. If request returns 401:
   - Try to refresh token
   - Retry original request once
   - If refresh fails, log out user
```

### 4. App Lifecycle Integration
```swift
// App becomes active:
- Restart TokenMonitor if user is logged in

// App goes to background:
- Stop TokenMonitor to save resources

// User logs out:
- Clear all tokens from Keychain
- Stop TokenMonitor
```

## Implementation Details

### Token Expiration Storage
```swift
// When receiving tokens from login/refresh:
if let expiresIn = response.expires_in {
    let expirationTime = Date().addingTimeInterval(TimeInterval(expiresIn))
    KeychainHelper.set(String(expirationTime.timeIntervalSince1970), forKey: "tokenExpirationTime")
}
```

### Proactive Request Validation
```swift
// Before making authenticated requests:
if await isTokenExpiredOrExpiringSoon() {
    let refreshed = await refreshToken()
    if !refreshed {
        return nil // Request will fail
    }
}
```

### Background Monitoring
```swift
// TokenMonitor schedules refresh:
let timeUntilRefresh = expirationTime.timeIntervalSinceNow - refreshBuffer
if timeUntilRefresh > 0 {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: timeUntilRefresh, repeats: false) { _ in
        Task { await self.refreshTokenIfNeeded() }
    }
}
```

## Debug Tools

*No debug view is present in production or development builds. All token refresh logic is automatic and transparent to the user.*

## Benefits

1. **Seamless User Experience**: No 401 errors during normal usage
2. **Battery Efficient**: Only monitors when app is active
3. **Secure**: All tokens stored in Keychain
4. **Robust**: Multiple fallback mechanisms

## Testing

### Manual Testing
1. Log in to the app
2. Wait for token expiration (or set a short expiry in backend for testing)
3. Monitor the app logs for automatic refresh events
4. Verify automatic refresh when timer reaches 0

### Simulating Token Expiry
1. Wait for token to expire naturally (15 minutes)
2. Or manually trigger refresh via API tools if needed

## Troubleshooting

### Common Issues

1. **Token not refreshing automatically**
   - Check if TokenMonitor is started (see logs)
   - Verify expiration time is stored correctly
   - Check network connectivity

2. **401 errors still occurring**
   - Verify refresh token is valid
   - Check if backend refresh endpoint is working
   - Ensure proper error handling in refresh flow

3. **Monitor not starting**
   - Check app lifecycle integration
   - Verify user is logged in when starting monitor
   - Check for any exceptions in TokenMonitor

### Debug Commands
```swift
// Check token status manually in code
await isTokenExpiredOrExpiringSoon()

// Get time until expiration
// (add a print statement or breakpoint in TokenMonitor)

// Manually refresh token
await NetworkManager.shared.refreshToken()

// Restart monitor
TokenMonitor.shared.startMonitoring()
```

## Backend Requirements

Your backend should support:
1. **Login Response**: Include `expires_in` field
2. **Refresh Endpoint**: `/auth/refresh` with refresh token
3. **Refresh Response**: Include new `access_token` and `expires_in`
4. **Proper 401 Responses**: For expired tokens

## Security Considerations

1. **Keychain Storage**: All tokens stored securely in iOS Keychain
2. **Automatic Cleanup**: Tokens cleared on logout
3. **No Token Logging**: Tokens are never logged to console
4. **HTTPS Only**: All API calls use secure connections
5. **Token Rotation**: Refresh tokens should be rotated on use (backend responsibility)

## Future Enhancements

1. **Token Refresh Retry Logic**: Exponential backoff for failed refreshes
2. **Offline Token Caching**: Handle token refresh when app comes back online
3. **Multiple Refresh Tokens**: Support for multiple concurrent sessions
4. **Token Analytics**: Track refresh patterns for optimization 