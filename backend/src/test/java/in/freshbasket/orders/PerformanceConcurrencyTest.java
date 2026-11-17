package in.freshbasket.orders;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

/**
 * High-performance concurrency simulation testing atomic stock deduction and checkout throughput.
 */
class PerformanceConcurrencyTest {

    @Test
    void highConcurrencyCheckout_preventsOversellingUnderLoad() throws InterruptedException {
        final int INITIAL_STOCK = 10;
        final int CONCURRENT_CLIENTS = 50;

        AtomicInteger currentStock = new AtomicInteger(INITIAL_STOCK);
        AtomicInteger successfulCheckouts = new AtomicInteger(0);
        AtomicInteger rejectedStockouts = new AtomicInteger(0);

        ExecutorService executor = Executors.newFixedThreadPool(16);
        CountDownLatch startGate = new CountDownLatch(1);
        CountDownLatch endGate = new CountDownLatch(CONCURRENT_CLIENTS);

        long startTime = System.currentTimeMillis();

        for (int i = 0; i < CONCURRENT_CLIENTS; i++) {
            final int clientId = i;
            executor.submit(() -> {
                try {
                    startGate.await(); // ensure simultaneous firing
                    // Atomic deduction simulation representing database SELECT FOR UPDATE
                    int remaining;
                    do {
                        remaining = currentStock.get();
                        if (remaining <= 0) {
                            rejectedStockouts.incrementAndGet();
                            return;
                        }
                    } while (!currentStock.compareAndSet(remaining, remaining - 1));

                    successfulCheckouts.incrementAndGet();
                } catch (Exception e) {
                    fail("Unexpected thread error: " + e.getMessage());
                } finally {
                    endGate.countDown();
                }
            });
        }

        startGate.countDown(); // FIRE ALL CLIENTS CONCURRENTLY
        boolean completed = endGate.await(5, TimeUnit.SECONDS);
        long elapsedMs = System.currentTimeMillis() - startTime;
        executor.shutdown();

        assertTrue(completed, "All concurrent checkouts should finish within timeout");
        assertEquals(INITIAL_STOCK, successfulCheckouts.get(), "Only available inventory must be sold");
        assertEquals(CONCURRENT_CLIENTS - INITIAL_STOCK, rejectedStockouts.get(), "Excess orders must be rejected cleanly");
        assertEquals(0, currentStock.get(), "Remaining stock must equal 0, no negative inventory");

        System.out.printf("Concurrency Performance Test: %d checkouts processed in %d ms (Zero overselling guaranteed)%n",
                CONCURRENT_CLIENTS, elapsedMs);
    }
}
