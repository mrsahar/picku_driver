## Driver Chat: Local History & Notifications

### Local Chat History (Client-Side)

- Chat messages between driver and passenger are stored locally using `sqflite` via `DatabaseHelper`:
  - Table: `ride_chat_messages` in `picku_driver.db`.
  - Columns: `ride_id`, `sender_id`, `sender_role`, `message`, `timestamp`.
- The unified SignalR layer (`UnifiedSignalRService`) is the single source of truth for in-memory chat:
  - Incoming SignalR events (`ReceiveMessage`, `ReceiveRideChatHistory`) are mapped to `ChatMessage` models and pushed into `rideChatMessages`.
  - Every sent/received message is also persisted to the `ride_chat_messages` table.
- When `ChatController` loads a chat:
  - It first calls `UnifiedSignalRService.getLocalRideChatHistory(rideId)` and applies those messages to the UI immediately.
  - It then requests server history via `loadRideChatHistory(rideId)` (if the hub is connected) so any missing messages are merged and re-persisted.
  - Leaving the chat screen clears only in-memory state, **not** the local DB, so history survives app restarts.

### In-App Chat Notifications

- Notifications are handled by `ChatNotificationService` using `flutter_local_notifications`:
  - Initialized in `InitialBinding` and configured once at app startup.
  - On init, it calls `checkNotificationPermission()` to sync the permission flag with the OS state.
- `UnifiedSignalRService._handleRideChatMessage` triggers notifications:
  - Determines whether a message is from the current driver or the passenger.
  - For passenger messages only, it calls `showChatMessageNotification(...)` with sender name, text, and `rideId`.
  - `ChatNotificationService` suppresses notifications when `isOnChatScreen` is `true` (set by `ChatController` when chat is visible).
  - Notifications are also suppressed if the OS-level permission is not granted.

### SignalR Resilience for Chat

- `UnifiedSignalRService` uses automatic reconnect with a backoff strategy.
- On reconnection (`onreconnected` handler):
  - Connection flags are restored.
  - If there is an active `currentRideId`, the service automatically:
    - Re-joins the ride chat group via `joinRideChat(currentRideId)`.
    - Requests fresh chat history via `loadRideChatHistory(currentRideId)`.
- Connectivity changes from `InternetConnectivityService` trigger `_attemptReconnection()`, which in turn calls `connect()` until the hub is healthy again.

### Manual Test Checklist

1. **History persistence**
   - Start a ride, open chat, exchange a few messages.
   - Close `ChatScreen`, reopen it for the same ride: messages from this device should appear instantly from local storage.
   - Kill and relaunch the app, navigate back to the same ride chat: history should still be visible.
2. **Notifications while not on chat screen**
   - With the app open but not on `ChatScreen`, send a message from the passenger side.
   - Confirm a local notification appears with correct sender name and message preview and that tapping it navigates to the right chat.
3. **No duplicate notifications while chatting**
   - While viewing `ChatScreen`, send a message from the passenger.
   - Verify the message appears in the list but no in-app notification is shown.
4. **Reconnection behaviour**
   - With an active ride chat, temporarily disable network, send a message from passenger, then re-enable network.
   - Confirm the SignalR connection recovers, rejoins the ride chat, and that new messages (and history) are visible and persisted locally.

