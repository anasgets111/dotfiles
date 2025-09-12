# Quickshell.Services.Notifications — Definitions

Types for implementing a notification daemon:

- Notification — A notification emitted by a NotificationServer.
- NotificationAction — An action associated with a Notification.
- NotificationCloseReason — The reason a Notification was closed.
- NotificationServer — Desktop Notifications Server.
- NotificationUrgency — The urgency level of a Notification.

---

## Notification: QObject

import Quickshell.Services.Notifications

A notification emitted by a NotificationServer.

NOTE: This type is Retainable. It can be retained after destruction if necessary.

### Properties

- inlineReplyPlaceholder: string  
  The placeholder text/button caption for the inline reply.

- actions: list<NotificationAction>  
  Actions that can be taken for this notification.

- appName: string  
  The sending application's name.

- image: string  
  An image associated with the notification. Often a profile picture in IM apps.

- lastGeneration: bool  
  True if carried over from last generation when quickshell reloaded.  
  Only set if NotificationServer.keepOnReload is true.

- resident: bool  
  If true, the notification will not be destroyed after an action is invoked.

- appIcon: string  
  The sending application’s icon. If none provided, one from an associated desktop entry will be retrieved.

- hints: unknown  
  All hints sent by the client application as a JavaScript object (many common hints exposed via other properties).

- hasInlineReply: bool  
  If true, the notification has an inline reply action.  
  A quick reply text field should be displayed and the reply can be sent using sendInlineReply().

- id: int  
  Id of the notification as given to the client.

- expireTimeout: real  
  Time in seconds the notification should be valid for.

- body: string  
  The body text. No details provided.

- hasActionIcons: bool  
  If actions associated with this notification have icons available.  
  See NotificationAction.identifier for details.

- summary: string  
  The summary/title associated with this notification, or "" if none.

- urgency: NotificationUrgency  
  The urgency level.

- desktopEntry: string  
  The name of the sender’s desktop entry or "" if none was supplied.

- tracked: bool  
  If the notification is tracked by the notification server.  
  Setting false is equivalent to calling dismiss().

- transient: bool  
  If true, skip any kind of persistence function like a notification area.

### Functions

- dismiss(): void  
  Destroy the notification and hint to the remote application that it was explicitly closed by the user.

- expire(): void  
  Destroy the notification and hint to the remote application that it has timed out.

- sendInlineReply(replyText: string): void  
  Send an inline reply to the notification with an inline reply action.  
  WARNING: Only callable if hasInlineReply is true and the server has NotificationServer.inlineReplySupported set to true.

### Signals

- closed(reason: NotificationCloseReason)  
  Emitted when a notification has been closed.  
  The notification object will be destroyed as soon as all signal handlers exit.

---

## NotificationAction: QObject

import Quickshell.Services.Notifications

See Notification.actions.

### Properties

- identifier: string  
  The identifier of the action. When Notification.hasActionIcons is true, this will be an icon name. When false, this property is irrelevant.

- text: string  
  The localized text that should be displayed on a button.

### Functions

- invoke(): void  
  Invoke the action. If Notification.resident is false it will be dismissed.

---

## NotificationCloseReason: QObject (enum)

import Quickshell.Services.Notifications

See Notification.closed().

### Functions

- toString(value: NotificationCloseReason): string

### Variants

- CloseRequested — The remote application requested the notification be removed.
- Dismissed — The notification was explicitly dismissed by the user.
- Expired — The notification expired due to a timeout.

---

## NotificationServer: QObject

import Quickshell.Services.Notifications

An implementation of the Desktop Notifications Specification for receiving notifications from external applications.

The server does not advertise most capabilities by default. See individual properties.

### Properties

- imageSupported: bool  
  Advertise support for images. Defaults to false.

- trackedNotifications: ObjectModel<Notification> (readonly)  
  All notifications currently tracked by the server.

- actionsSupported: bool  
  Advertise support for notification actions. Defaults to false.

- extraHints: list<string>  
  Extra hints to expose to notification clients.

- inlineReplySupported: bool  
  Advertise support for inline replies. Defaults to false.

- bodyHyperlinksSupported: bool  
  Advertise body text as supporting hyperlinks per the specification. Defaults to false.  
  Returned notifications may still contain hyperlinks even if false (hint).

- keepOnReload: bool  
  If notifications should be re-emitted when quickshell reloads. Defaults to true.  
  Notification.lastGeneration will be set on notifications from the prior generation.

- persistenceSupported: bool  
  Advertise that it can persist notifications in the background after going offscreen. Defaults to false.

- actionIconsSupported: bool  
  Advertise actions as supporting the display of icons. Defaults to false.

- bodySupported: bool  
  Advertise body text as supported by the notification server. Defaults to true.  
  Returned notifications are likely to return body text even if false (hint).

- bodyMarkupSupported: bool  
  Advertise body text as supporting markup as described in the specification. Defaults to false.  
  Returned notifications may still contain markup even if false (hint). To avoid rendering, set Text.textFormat to PlainText.

- bodyImagesSupported: bool  
  Advertise body text as supporting images as described in the specification. Defaults to false.  
  Returned notifications may still contain images even if false (hint).

### Signals

- notification(notification: Notification)  
  Sent when a notification is received by the server.  
  If it should not be discarded, set its tracked property to true.

---

## NotificationUrgency: QObject (enum)

import Quickshell.Services.Notifications

See Notification.urgency.

### Functions

- toString(value: NotificationUrgency): string

### Variants

- Low
- Critical
- Normal
