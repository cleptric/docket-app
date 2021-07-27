<?php
declare(strict_types=1);

namespace App\Model\Entity;

use Cake\ORM\Entity;
use DateTimeInterface;

/**
 * CalendarItem Entity
 *
 * @property int $id
 * @property int $calendar_source_id
 * @property string $provider_id
 * @property string $title
 * @property \Cake\I18n\FrozenTime|null $start_time
 * @property \Cake\I18n\FrozenTime|null $end_time
 * @property \Cake\I18n\FrozenDate|null $start_date
 * @property \Cake\I18n\FrozenDate|null $end_date
 * @property bool $all_day
 * @property string|null $html_link
 * @property \Cake\I18n\FrozenTime $created
 * @property \Cake\I18n\FrozenTime $modified
 *
 * @property \App\Model\Entity\CalendarSource $calendar_source
 * @property \App\Model\Entity\Provider $provider
 */
class CalendarItem extends Entity
{
    /**
     * Fields that can be mass assigned using newEntity() or patchEntity().
     *
     * Note that when '*' is set to true, this allows all unspecified fields to
     * be mass assigned. For security purposes, it is advised to set '*' to false
     * (or remove it), and explicitly make individual fields accessible as needed.
     *
     * @var array
     */
    protected $_accessible = [
        'calendar_source_id' => true,
        'provider_id' => true,
        'title' => true,
        'start_date' => true,
        'start_time' => true,
        'end_date' => true,
        'end_time' => true,
        'all_day' => true,
        'html_link' => true,
        'created' => true,
        'modified' => true,
        'calendar_source' => true,
        'provider' => true,
    ];

    protected $_hidden = ['calendar_source'];

    protected $_virtual = ['color'];

    public function getStart(): ?DateTimeInterface
    {
        if ($this->start_date) {
            return $this->start_date;
        }

        return $this->start_time;
    }

    public function getEnd(): ?DateTimeInterface
    {
        if ($this->end_date) {
            return $this->end_date;
        }

        return $this->end_time;
    }

    protected function _getColor()
    {
        if (isset($this->calendar_source)) {
            return $this->calendar_source->color;
        }

        return 1;
    }
}