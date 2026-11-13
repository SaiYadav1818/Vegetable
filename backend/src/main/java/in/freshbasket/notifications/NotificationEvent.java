package in.freshbasket.notifications;

import java.util.Set;

public record NotificationEvent(String eventType, String deduplicationKey, Long orderId,
        String title, String body, Set<Long> recipientIds) {}
