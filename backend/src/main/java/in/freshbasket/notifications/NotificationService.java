package in.freshbasket.notifications;

import com.google.firebase.messaging.*;
import in.freshbasket.user.*;
import java.time.Instant;
import java.util.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class NotificationService {
    private static final Logger log=LoggerFactory.getLogger(NotificationService.class);
    private final UserRepository users; private final DeviceTokenRepository devices; private final NotificationRepository notifications;
    private final Optional<FirebaseMessaging> messaging;
    public NotificationService(UserRepository users,DeviceTokenRepository devices,NotificationRepository notifications,Optional<FirebaseMessaging> messaging){this.users=users;this.devices=devices;this.notifications=notifications;this.messaging=messaging;}

    @Transactional public void register(String email,NotificationDtos.RegisterDeviceRequest request){
        AppUser user=current(email);String token=request.token().trim();
        DeviceToken existing=devices.findByToken(token).orElseGet(()->devices.findByUser_IdAndDeviceId(user.getId(),request.deviceId()).orElse(null));
        if(existing==null)devices.save(new DeviceToken(user,request.deviceId(),token,request.platform()));
        else existing.update(user,token,request.platform());
    }
    @Transactional public void remove(String email,String deviceId){AppUser user=current(email);devices.findLocked(user.getId(),deviceId).ifPresent(DeviceToken::deactivate);}
    @Transactional(readOnly=true) public NotificationDtos.NotificationPage list(String email,Pageable pageable){
        AppUser user=current(email);Page<NotificationDtos.NotificationResponse> page=notifications.findByUser_Id(user.getId(),pageable).map(NotificationService::dto);
        return new NotificationDtos.NotificationPage(page,notifications.countByUser_IdAndReadAtIsNull(user.getId()));
    }
    @Transactional public void markRead(String email,long id){AppUser user=current(email);NotificationRecord record=notifications.findById(id).filter(n->n.getUserId().equals(user.getId())).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Notification not found"));record.read();}
    @Transactional public List<Long> enqueue(NotificationEvent event){
        List<Long> ids=new ArrayList<>();
        for(Long userId:event.recipientIds()){
            if(notifications.existsByUser_IdAndDeduplicationKey(userId,event.deduplicationKey()))continue;
            users.findById(userId).filter(AppUser::isActive).ifPresent(user->{
                NotificationRecord saved=notifications.save(new NotificationRecord(user,event.orderId(),event.eventType(),event.deduplicationKey(),event.title(),event.body()));ids.add(saved.getId());
            });
        }
        return ids;
    }
    @Transactional(readOnly=true) public List<Long> due(){return notifications.findDueIds(Instant.now(),PageRequest.of(0,100));}
    @Transactional public DeliveryPayload claim(long id){
        NotificationRecord record=notifications.findLocked(id).orElse(null);if(record==null||!(record.getDeliveryStatus().equals("PENDING")||record.getDeliveryStatus().equals("SENDING"))||record.getNextAttemptAt().isAfter(Instant.now()))return null;
        record.sending();List<DeviceToken> tokens=devices.findByUser_IdAndActiveTrue(record.getUserId());
        return new DeliveryPayload(record.getId(),record.getUserId(),record.getOrderId(),record.getEventType(),record.getTitle(),record.getBody(),tokens.stream().map(t->new DevicePayload(t.getId(),t.getToken())).toList(),record.getAttempts());
    }
    public void send(DeliveryPayload payload){
        if(payload.tokens().isEmpty()){finishNoDevices(payload.id());return;}
        FirebaseMessaging sender=messaging.orElse(null);
        if(sender==null){retry(payload.id(),"Firebase Admin credentials are not configured");return;}
        int successes=0;boolean failed=false;
        for(DevicePayload token:payload.tokens())try{
            Message message=Message.builder().setToken(token.token()).setNotification(Notification.builder().setTitle(payload.title()).setBody(payload.body()).build())
                    .putData("notificationId",String.valueOf(payload.id())).putData("eventType",payload.eventType()).putData("orderId",payload.orderId()==null?"":String.valueOf(payload.orderId()))
                    .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).setTtl(3600_000L).setNotification(AndroidNotification.builder().setTag("freshbasket-"+payload.id()).build()).build()).build();
            sender.send(message);successes++;
        }catch(FirebaseMessagingException error){
            failed=true;log.warn("FCM send failed notificationId={} tokenId={} code={}",payload.id(),token.id(),error.getMessagingErrorCode());
            if(error.getMessagingErrorCode()==MessagingErrorCode.UNREGISTERED)devices.deactivateById(token.id());
        }catch(RuntimeException error){failed=true;log.error("Unexpected FCM failure notificationId={} tokenId={}",payload.id(),token.id(),error);}
        if(successes>0&&!failed)markSent(payload.id());else if(successes>0)markSent(payload.id());else retry(payload.id(),"FCM rejected delivery to all active devices");
    }
    @Transactional public void markSent(long id){notifications.findLocked(id).ifPresent(NotificationRecord::sent);}
    @Transactional public void retry(long id,String reason){notifications.findLocked(id).ifPresent(n->n.retry(reason));}
    @Transactional public void finishNoDevices(long id){notifications.findLocked(id).ifPresent(NotificationRecord::noDevices);}
    private AppUser current(String email){return users.findByEmail(email).filter(AppUser::isActive).orElseThrow(()->new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Active account required"));}
    private static NotificationDtos.NotificationResponse dto(NotificationRecord n){return new NotificationDtos.NotificationResponse(n.getId(),n.getEventType(),n.getTitle(),n.getBody(),n.getOrderId(),n.getCreatedAt(),n.getReadAt(),n.getReadAt()==null);}
    public record DeliveryPayload(Long id,Long userId,Long orderId,String eventType,String title,String body,List<DevicePayload> tokens,int attempts){}
    public record DevicePayload(Long id,String token){}
}
