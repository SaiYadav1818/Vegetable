package in.freshbasket.notifications;

import java.util.concurrent.Executor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.*;
import org.springframework.scheduling.annotation.*;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.*;

@Configuration @EnableAsync @EnableScheduling
class NotificationAsyncConfiguration {
    @Bean(name="notificationExecutor") Executor notificationExecutor(){ThreadPoolTaskExecutor executor=new ThreadPoolTaskExecutor();executor.setCorePoolSize(2);executor.setMaxPoolSize(4);executor.setQueueCapacity(500);executor.setThreadNamePrefix("freshbasket-notify-");executor.initialize();return executor;}
}

@Component
class NotificationEventListener {
    private final NotificationService service;private final NotificationDeliveryWorker worker;
    NotificationEventListener(NotificationService service,NotificationDeliveryWorker worker){this.service=service;this.worker=worker;}
    @Async("notificationExecutor") @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT)
    public void onEvent(NotificationEvent event){for(Long id:service.enqueue(event))worker.deliver(id);}
}

@Component
class NotificationDeliveryWorker {
    private final NotificationService service;
    NotificationDeliveryWorker(NotificationService service){this.service=service;}
    @Async("notificationExecutor") public void deliver(Long id){try{NotificationService.DeliveryPayload payload=service.claim(id);if(payload!=null)service.send(payload);}catch(RuntimeException error){LoggerFactory.getLogger(getClass()).error("Notification delivery worker failed id={}",id,error);service.retry(id,"Notification delivery worker failed");}}
}

@Component
class NotificationRetryScheduler {
    private final NotificationService service;private final NotificationDeliveryWorker worker;
    NotificationRetryScheduler(NotificationService service,NotificationDeliveryWorker worker){this.service=service;this.worker=worker;}
    @Scheduled(fixedDelayString="${app.notifications.retry-delay-ms:30000}") public void retryDue(){for(Long id:service.due())worker.deliver(id);}
}
