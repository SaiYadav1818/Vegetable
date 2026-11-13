package in.freshbasket.notifications;

import jakarta.validation.Valid;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/notifications")
public class NotificationController {
    private final NotificationService notifications;
    public NotificationController(NotificationService notifications){this.notifications=notifications;}
    @PostMapping("/devices") public void register(Authentication auth,@Valid @RequestBody NotificationDtos.RegisterDeviceRequest request){notifications.register(auth.getName(),request);}
    @DeleteMapping("/devices/{deviceId}") public void remove(Authentication auth,@PathVariable String deviceId){notifications.remove(auth.getName(),deviceId);}
    @GetMapping public NotificationDtos.NotificationPage list(Authentication auth,@PageableDefault(size=30,sort="createdAt",direction=Sort.Direction.DESC) Pageable pageable){return notifications.list(auth.getName(),pageable);}
    @PutMapping("/{id}/read") public void markRead(Authentication auth,@PathVariable long id){notifications.markRead(auth.getName(),id);}
}
