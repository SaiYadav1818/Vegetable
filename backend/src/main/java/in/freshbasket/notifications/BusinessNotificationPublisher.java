package in.freshbasket.notifications;

import in.freshbasket.catalog.Product;
import in.freshbasket.orders.CustomerOrder;
import in.freshbasket.orders.OrderStatus;
import in.freshbasket.user.*;
import java.math.BigDecimal;
import java.util.*;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

@Component
public class BusinessNotificationPublisher {
    private final ApplicationEventPublisher events;
    private final UserRepository users;
    public BusinessNotificationPublisher(ApplicationEventPublisher events,UserRepository users){this.events=events;this.users=users;}

    public void orderPlaced(CustomerOrder order){
        publish("ORDER_PLACED","ORDER_PLACED:"+order.getId(),order,"New order received","Order "+order.getOrderNumber()+" was placed.",adminIds());
    }
    public void orderStatus(CustomerOrder order,OrderStatus status){
        String type=switch(status){case ACCEPTED->"ORDER_ACCEPTED";case REJECTED->"ORDER_REJECTED";case PREPARING->"ORDER_PREPARING";case READY_FOR_PICKUP->"ORDER_READY";case DRIVER_ASSIGNED->"DRIVER_ASSIGNED";case OUT_FOR_DELIVERY->"OUT_FOR_DELIVERY";case DELIVERED->"ORDER_DELIVERED";case CANCELLED->"ORDER_CANCELLED";case DELIVERY_FAILED->"DELIVERY_FAILED";default->null;};
        if(type==null)return;
        Set<Long> recipients=new HashSet<>();recipients.add(order.getCustomer().getId());
        if(status==OrderStatus.DELIVERED||status==OrderStatus.CANCELLED||status==OrderStatus.DELIVERY_FAILED)recipients.addAll(adminIds());
        String label=switch(status){case ACCEPTED->"was accepted";case REJECTED->"was rejected";case PREPARING->"is being prepared";case READY_FOR_PICKUP->"is ready for pickup";case DRIVER_ASSIGNED->"has a driver assigned";case OUT_FOR_DELIVERY->"is out for delivery";case DELIVERED->"was delivered";case CANCELLED->"was cancelled";case DELIVERY_FAILED->"delivery attempt failed";default->"was updated";};
        publish(type,type+":"+order.getId()+":"+status.name(),order,"Order update","Order "+order.getOrderNumber()+" "+label+".",recipients);
    }
    public void driverAssigned(CustomerOrder order,AppUser driver){
        publish("DRIVER_ASSIGNED","DRIVER_ASSIGNED_DRIVER:"+order.getId()+":"+driver.getId(),order,"New delivery assigned","Order "+order.getOrderNumber()+" is ready for delivery.",Set.of(driver.getId()));
    }
    public void lowStock(Product product,BigDecimal quantity,BigDecimal minimum,long transactionId){
        Set<Long> recipients=adminIds();String text=product.getName()+" stock is low ("+quantity.stripTrailingZeros().toPlainString()+" remaining).";
        events.publishEvent(new NotificationEvent("LOW_STOCK","LOW_STOCK:"+product.getId()+":"+transactionId,null,"Low stock alert",text,recipients));
    }
    private void publish(String type,String key,CustomerOrder order,String title,String body,Set<Long> recipients){
        events.publishEvent(new NotificationEvent(type,key,order.getId(),title,body,Set.copyOf(recipients)));
    }
    private Set<Long> adminIds(){return users.findByRoleAndActiveTrue(Role.ADMIN).stream().map(AppUser::getId).collect(java.util.stream.Collectors.toSet());}
}
