<?php

declare(strict_types=1);

namespace App\Controller;

use App\Model\Entity\CalendarSource;
use App\Service\CalendarService;

/**
 * CalendarSources Controller
 *
 * @property \App\Model\Table\CalendarSourcesTable $CalendarSources
 * @method \App\Model\Entity\CalendarSource[]|\Cake\Datasource\ResultSetInterface paginate($object = null, array $settings = [])
 */
class CalendarSourcesController extends AppController
{
    protected function getSource(): CalendarSource
    {
        $query = $this->CalendarSources
            ->find()
            ->contain('CalendarProviders')
            ->where([
                // 'CalendarSources.provider_id' => $this->request->getParam('providerId'),
                'CalendarSources.id' => $this->request->getParam('id'),
                // 'CalendarProviders.user_id' => $this->request->getAttribute('identity')->id,
            ]);

        return $query->firstOrFail();
    }

    /**
     * Add method
     *
     * @param string|null $providerId Calendar Provider id.
     * @return \Cake\Http\Response|null|void Renders view
     * @throws \Cake\Datasource\Exception\RecordNotFoundException When record not found.
     */
    public function add(CalendarService $service, $providerId = null)
    {
        $provider = $this->CalendarSources->CalendarProviders->get($providerId, [
            'contain' => ['CalendarSources'],
        ]);
        $this->Authorization->authorize($provider, 'edit');
        if ($this->request->is('post')) {
            $source = $this->CalendarSources->newEntity($this->request->getData());
            if ($this->CalendarSources->save($source)) {
                $this->redirect(['_name' => 'calendarsources:add', 'providerId' => $providerId]);
            } else {
                $this->Flash->error('Could not add that calendar.');
            }
        }
        $service->setAccessToken($provider->access_token);
        $calendars = $service->listCalendars();

        $this->set('calendarProvider', $provider);
        $this->set('unlinked', $calendars);
        $this->set('referer', $this->referer(['_name' => 'tasks:today']));
    }

    public function sync(CalendarService $service)
    {
        $user = $this->request->getAttribute('identity');
        $source = $this->getSource();
        $this->Authorization->authorize($source->calendar_provider, 'sync');

        $service->setAccessToken($source->calendar_provider->access_token);

        // TODO add policy check.
        $service->syncEvents($user, $source);
    }

    /**
     * View method
     *
     * @param string|null $id Calendar Source id.
     * @return \Cake\Http\Response|null|void Renders view
     * @throws \Cake\Datasource\Exception\RecordNotFoundException When record not found.
     */
    public function view()
    {
        $source = $this->getSource();
        $this->Authorization->authorize($calendarSource);

        $this->set(compact('calendarSource'));
    }

    /**
     * Edit method
     *
     * @param string|null $id Calendar Source id.
     * @return \Cake\Http\Response|null|void Redirects on successful edit, renders view otherwise.
     * @throws \Cake\Datasource\Exception\RecordNotFoundException When record not found.
     */
    public function edit()
    {
        $calendarSource = $this->getSource();

        if ($this->request->is(['patch', 'post', 'put'])) {
            $calendarSource = $this->CalendarSources->patchEntity($calendarSource, $this->request->getData());
            if ($this->CalendarSources->save($calendarSource)) {
                $this->Flash->success(__('The calendar source has been saved.'));

                return $this->redirect(['action' => 'index']);
            }
            $this->Flash->error(__('The calendar source could not be saved. Please, try again.'));
        }
        $calendarProviders = $this->CalendarSources->CalendarProviders->find('list', ['limit' => 200]);
        $providers = $this->CalendarSources->Providers->find('list', ['limit' => 200]);
        $this->set(compact('calendarSource', 'calendarProviders', 'providers'));
    }

    /**
     * Delete method
     *
     * @return \Cake\Http\Response|null|void Redirects to index.
     * @throws \Cake\Datasource\Exception\RecordNotFoundException When record not found.
     */
    public function delete()
    {
        $this->request->allowMethod(['post', 'delete']);
        $calendarSource = $this->getSource();
        $this->Authorization->authorize($calendarSource->calendar_provider);

        if ($this->CalendarSources->delete($calendarSource)) {
            $this->Flash->success(__('The calendar source has been deleted.'));
        } else {
            $this->Flash->error(__('The calendar source could not be deleted. Please, try again.'));
        }

        return $this->redirect([
            'action' => 'add',
            'providerId' => $this->request->getParam('providerId')
        ]);
    }
}
