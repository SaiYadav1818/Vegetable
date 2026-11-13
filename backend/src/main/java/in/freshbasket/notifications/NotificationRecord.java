package in.freshbasket.notifications;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name="notifications", uniqueConstraints=@UniqueConstraint(name="uq_notifications_dedupe", columnNames={"user_id","deduplication_key"}), indexes=@Index(name="idx_notifications_delivery", columnList="delivery_status,next_attempt_at"))
public class NotificationRecord {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY, optional=false) @JoinColumn(name="user_id",nullable=false) private AppUser user;
    @Column(name="order_id") private Long orderId;
    @Column(name="event_type",nullable=false,length=40) private String eventType;
    @Column(name="deduplication_key",nullable=false,length=160) private String deduplicationKey;
    @Column(nullable=false,length=120) private String title;
    @Column(nullable=false,length=240) private String body;
    @Column(name="read_at") private Instant readAt;
    @Column(name="delivery_status",nullable=false,length=16) private String deliveryStatus="PENDING";
    @Column(nullable=false) private int attempts;
    @Column(name="next_attempt_at",nullable=false) private Instant nextAttemptAt=Instant.now();
    @Column(name="last_error",length=240) private String lastError;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @PrePersist void create(){createdAt=Instant.now();}
    protected NotificationRecord(){}
    public NotificationRecord(AppUser user,Long orderId,String eventType,String dedupe,String title,String body){this.user=user;this.orderId=orderId;this.eventType=eventType;this.deduplicationKey=dedupe;this.title=title;this.body=body;}
    public Long getId(){return id;} public Long getUserId(){return user.getId();} public Long getOrderId(){return orderId;} public String getEventType(){return eventType;} public String getTitle(){return title;} public String getBody(){return body;} public String getDeduplicationKey(){return deduplicationKey;} public Instant getReadAt(){return readAt;} public Instant getCreatedAt(){return createdAt;} public String getDeliveryStatus(){return deliveryStatus;} public int getAttempts(){return attempts;} public Instant getNextAttemptAt(){return nextAttemptAt;}
    public void read(){if(readAt==null)readAt=Instant.now();}
    public void sending(){deliveryStatus="SENDING";attempts++;nextAttemptAt=Instant.now().plusSeconds(300);}
    public void sent(){deliveryStatus="SENT";lastError=null;}
    public void retry(String message){lastError=message;deliveryStatus=attempts>=8?"FAILED":"PENDING";nextAttemptAt=Instant.now().plusSeconds(Math.min(3600L,30L*(1L<<Math.min(attempts,7))));}
    public void noDevices(){deliveryStatus="NO_DEVICE";}
}
