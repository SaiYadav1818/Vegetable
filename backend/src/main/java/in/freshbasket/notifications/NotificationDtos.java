package in.freshbasket.notifications;

import jakarta.validation.constraints.*;
import java.time.Instant;

public final class NotificationDtos {
    private NotificationDtos(){}
    public record RegisterDeviceRequest(@NotBlank @Size(max=128) String deviceId,@NotBlank @Size(max=512) String token,@NotNull DevicePlatform platform){}
    public record NotificationResponse(long id,String eventType,String title,String body,Long orderId,Instant createdAt,Instant readAt,boolean unread){}
    public record NotificationPage(org.springframework.data.domain.Page<NotificationResponse> items,long unreadCount){}
}
