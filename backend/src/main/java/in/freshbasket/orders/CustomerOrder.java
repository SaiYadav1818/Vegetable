package in.freshbasket.orders;

import in.freshbasket.user.AppUser;
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity @Table(name="orders",indexes={@Index(name="idx_orders_customer_created",columnList="customer_user_id,created_at"),@Index(name="idx_orders_status_created",columnList="status,created_at")})
public class CustomerOrder {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="order_number",nullable=false,unique=true,length=32) private String orderNumber;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="customer_user_id",nullable=false) private AppUser customer;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=24) private OrderStatus status;
    @Column(name="payment_method",nullable=false,length=16) private String paymentMethod="COD";
    @Enumerated(EnumType.STRING) @Column(name="payment_status",nullable=false,length=16) private PaymentStatus paymentStatus=PaymentStatus.PENDING;
    @Column(nullable=false,precision=12,scale=2) private BigDecimal subtotal;
    @Column(name="delivery_charge",nullable=false,precision=12,scale=2) private BigDecimal deliveryCharge;
    @Column(name="total_amount",nullable=false,precision=12,scale=2) private BigDecimal totalAmount;
    @Column(name="recipient_name",nullable=false,length=120) private String recipientName;
    @Column(name="recipient_phone",nullable=false,length=20) private String recipientPhone;
    @Column(name="address_line",nullable=false,length=300) private String addressLine;
    @Column(name="house_number",length=100) private String houseNumber;
    @Column(nullable=false,length=120) private String area;
    @Column(length=160) private String landmark;
    @Column(nullable=false,length=6) private String pincode;
    @Column(name="delivery_instructions",length=500) private String deliveryInstructions;
    @Column(name="delivery_date",nullable=false) private LocalDate deliveryDate;
    @Enumerated(EnumType.STRING) @Column(name="delivery_slot",nullable=false,length=20) private DeliverySlot deliverySlot;
    @Column(precision=10,scale=7) private BigDecimal latitude;
    @Column(precision=10,scale=7) private BigDecimal longitude;
    @Column(name="created_at",nullable=false,updatable=false) private Instant createdAt;
    @Column(name="updated_at",nullable=false) private Instant updatedAt;
    @PrePersist void create(){createdAt=updatedAt=Instant.now();} @PreUpdate void update(){updatedAt=Instant.now();}
    protected CustomerOrder(){}
    public CustomerOrder(String number,AppUser customer,BigDecimal subtotal,BigDecimal deliveryCharge,BigDecimal total,
            String name,String phone,String address,String house,String area,String landmark,String pincode,String instructions,
            LocalDate date,DeliverySlot slot,BigDecimal latitude,BigDecimal longitude){
        this.orderNumber=number;this.customer=customer;this.status=OrderStatus.PLACED;this.subtotal=subtotal;this.deliveryCharge=deliveryCharge;this.totalAmount=total;
        this.recipientName=name;this.recipientPhone=phone;this.addressLine=address;this.houseNumber=house;this.area=area;this.landmark=landmark;this.pincode=pincode;
        this.deliveryInstructions=instructions;this.deliveryDate=date;this.deliverySlot=slot;this.latitude=latitude;this.longitude=longitude;
    }
    public Long getId(){return id;} public String getOrderNumber(){return orderNumber;} public AppUser getCustomer(){return customer;} public OrderStatus getStatus(){return status;}
    public PaymentStatus getPaymentStatus(){return paymentStatus;} public BigDecimal getSubtotal(){return subtotal;} public BigDecimal getDeliveryCharge(){return deliveryCharge;} public BigDecimal getTotalAmount(){return totalAmount;}
    public String getRecipientName(){return recipientName;} public String getRecipientPhone(){return recipientPhone;} public String getAddressLine(){return addressLine;} public String getHouseNumber(){return houseNumber;}
    public String getArea(){return area;} public String getLandmark(){return landmark;} public String getPincode(){return pincode;} public String getDeliveryInstructions(){return deliveryInstructions;}
    public LocalDate getDeliveryDate(){return deliveryDate;} public DeliverySlot getDeliverySlot(){return deliverySlot;} public BigDecimal getLatitude(){return latitude;} public BigDecimal getLongitude(){return longitude;}
    public Instant getCreatedAt(){return createdAt;}
    public void status(OrderStatus value){status=value;}
    public void paymentStatus(PaymentStatus value){paymentStatus=value;}
}
