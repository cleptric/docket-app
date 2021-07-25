<?php
declare(strict_types=1);

namespace App\Test\TestCase\Controller;

use App\Test\TestCase\FactoryTrait;
use Cake\I18n\FrozenTime;
use Cake\TestSuite\IntegrationTestTrait;
use Cake\TestSuite\TestCase;

/**
 * App\Controller\GoogleNotificationsController Test Case
 *
 * @uses \App\Controller\GoogleNotificationsController
 */
class GoogleNotificationsControllerTest extends TestCase
{
    use FactoryTrait;
    use IntegrationTestTrait;

    /**
     * Fixtures
     *
     * @var array
     */
    protected $fixtures = [
        'app.Users',
        'app.CalendarProviders',
        'app.CalendarSources',
        'app.CalendarSubscriptions',
        'app.CalendarItems',
    ];

    public function tearDown(): void
    {
        parent::tearDown();

        FrozenTime::setTestNow(null);
    }

    /**
     * @vcr controller_calendarsources_sync.yml
     */
    public function testUpdateSuccess(): void
    {
        FrozenTime::setTestNow('2021-07-11 12:13:14');

        $provider = $this->makeCalendarProvider(1, 'test@example.com');
        $source = $this->makeCalendarSource($provider->id, 'primary', [
            'provider_id' => 'calendar-1',
        ]);
        $sub = $this->makeCalendarSubscription($source->id);

        $this->configRequest([
            'headers' => [
                'X-Goog-Channel-ID' => $sub->identifier,
                'X-Goog-Channel-Token' => $sub->channel_token,
                // Time is fixed in this test.
                'X-Goog-Channel-Expiration' => '2021-07-11 22:00:00',
            ],
        ]);
        $this->post('/google/calendar/notifications');
        $this->assertResponseOk();

        $items = $this->getTableLocator()->get('CalendarItems');
        $rows = $items->find()->all();
        $this->assertCount(3, $rows);
    }

    public function testUpdateInvalidToken(): void
    {
        $provider = $this->makeCalendarProvider(1, 'test@example.com');
        $this->makeCalendarSource($provider->id);

        $this->configRequest([
            'headers' => [
                'X-Goog-Channel-ID' => 'not-real',
                'X-Goog-Channel-Token' => 'no',
                'X-Google-Channel-Expiration' => 1234,
            ],
        ]);
        $this->post('/google/calendar/notifications');

        $this->assertResponseCode(400);
    }

    /**
     * @vcr calendarservice_sync_and_sub.yml
     */
    public function testUpdateExpiresSoon(): void
    {
        FrozenTime::setTestNow('2021-07-11 12:13:14');

        $provider = $this->makeCalendarProvider(1, 'test@example.com');
        $source = $this->makeCalendarSource($provider->id, 'primary', [
            'provider_id' => 'calendar-1',
        ]);
        $sub = $this->makeCalendarSubscription($source->id);

        $this->configRequest([
            'headers' => [
                'X-Goog-Channel-ID' => $sub->identifier,
                'X-Goog-Channel-Token' => $sub->channel_token,
                // Time is fixed in this test.
                'X-Goog-Channel-Expiration' => '2012-07-11 12:34:59',
            ],
        ]);
        $this->post('/google/calendar/notifications');
        $this->assertResponseOk();

        $items = $this->getTableLocator()->get('CalendarItems');
        $rows = $items->find()->all();
        $this->assertCount(1, $rows);

        $subs = $this->getTableLocator()->get('CalendarSubscriptions');
        $rows = $subs->find()->all();
        $this->assertCount(2, $rows, 'Should create another subscription.');
    }
}
