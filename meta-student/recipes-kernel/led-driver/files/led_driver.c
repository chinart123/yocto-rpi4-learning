#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>
#include <linux/timer.h>
#include <linux/delay.h>

#define LED_PIN 17
MODULE_AUTHOR("Chien Khoi");
MODULE_DESCRIPTION("A simple GPIO LED driver for Raspberry Pi");
MODULE_VERSION("1.0");
MODULE_LICENSE("GPL");

static struct timer_list blink_timer;
static int led_state = 0;
static void blink_callback(struct timer_list *t)
{
    led_state = !led_state;
    gpio_set_value(LED_PIN, led_state);
    mod_timer(&blink_timer, jiffies + msecs_to_jiffies(1000));
}

static int __init led_init(void)
{
    if (!gpio_is_valid(LED_PIN)) return -ENODEV;

    gpio_request(LED_PIN, "led-blink");
    gpio_direction_output(LED_PIN, 0);
    gpio_export(LED_PIN, false);

    timer_setup(&blink_timer, blink_callback, 0);
    mod_timer(&blink_timer, jiffies + msecs_to_jiffies(1000));

    pr_info("LED Driver: blinking on GPIO%d (pin 11)\n", LED_PIN);
    return 0;
}

static void __exit led_exit(void)
{
    del_timer_sync(&blink_timer);
    gpio_set_value(LED_PIN, 0);
    gpio_unexport(LED_PIN);
    gpio_free(LED_PIN);
    pr_info("LED Driver: unloaded\n");
}

module_init(led_init);
module_exit(led_exit);


