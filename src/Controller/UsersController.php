<?php
declare(strict_types=1);

namespace App\Controller;

use App\Model\Entity\User;
use Cake\Datasource\Exception\RecordNotFoundException;
use Cake\Event\EventInterface;
use Cake\Mailer\MailerAwareTrait;
use RuntimeException;

/**
 * Users Controller
 *
 * @property \App\Model\Table\UsersTable $Users
 */
class UsersController extends AppController
{
    use MailerAwareTrait;

    public function beforeFilter(EventInterface $event)
    {
        parent::beforeFilter($event);

        $this->Authentication->allowUnauthenticated([
            'add', 'login', 'resetPassword', 'newPassword',
        ]);
    }

    /**
     * Add method
     *
     * @return \Cake\Http\Response|null|void Redirects on successful add, renders view otherwise.
     */
    public function add()
    {
        $this->Authorization->skipAuthorization();

        $user = $this->Users->newEmptyEntity();
        if ($this->request->is('post')) {
            $user = $this->Users->newEntity($this->request->getData(), [
                'fields' => ['name', 'email', 'password', 'timezone'],
                'validate' => 'register',
            ]);
            if ($this->Users->save($user)) {
                $this->getMailer('Users')->send('verifyEmail', [$user]);
                $this->Authentication->setIdentity($user);
                $this->Users->Projects->createDefaultProject($user);
                $this->Flash->success(__('Your account has been created. We have sent an email to verify it.'));

                return $this->redirect(['_name' => 'tasks:today']);
            }
            $this->Flash->error(__('We could not complete your registration'));
            $this->set('errors', $this->flattenErrors($user->getErrors()));
        }
        $this->set(compact('user'));
    }

    /**
     * Edit method
     *
     * @return \Cake\Http\Response|null|void Redirects on successful edit, renders view otherwise.
     * @throws \Cake\Datasource\Exception\RecordNotFoundException When record not found.
     */
    public function edit()
    {
        $referer = $this->getReferer();
        $identity = $this->request->getAttribute('identity');
        $user = $this->Users->get($identity->id);
        $this->Authorization->authorize($user);

        if ($this->request->is(['patch', 'post', 'put'])) {
            $allowedFields = ['name', 'timezone', 'theme'];
            $user = $this->Users->patchEntity($user, $this->request->getData(), [
                'fields' => $allowedFields,
            ]);
            $email = $this->request->getData('unverified_email');
            if ($email) {
                $user->unverified_email = $email;
            }

            $emailChanged = $user->isDirty('unverified_email');
            if ($this->Users->save($user)) {
                if ($emailChanged) {
                    $this->getMailer('Users')->send('verifyEmail', [$user]);
                }
                $this->Flash->success(__('Your profile has been updated.'));

                return $this->redirect($referer);
            }
            $this->set('errors', $this->flattenErrors($user->getErrors()));
            $this->Flash->error(__('Your profile not be saved. Please, try again.'));
        }
        $this->set(compact('user', 'referer'));
    }

    /**
     * Update password for a logged in User.
     * Commonly accessed via edit profile.
     */
    public function updatePassword()
    {
        $referer = $this->getReferer();
        $identity = $this->request->getAttribute('identity');
        $user = $this->Users->get($identity->id);
        $this->Authorization->authorize($user, 'edit');

        $allowedFields = ['password', 'current_password', 'confirm_password'];
        if ($this->request->is(['patch', 'post', 'put'])) {
            $user = $this->Users->patchEntity($user, $this->request->getData(), [
                'fields' => $allowedFields,
                'validate' => 'updatePassword',
            ]);
            if ($this->Users->save($user)) {
                $this->Flash->success(__('Your password has been updated.'));
                $this->redirect($referer);
            } else {
                $this->Flash->error(__('Your password was not updated. Please, try again.'));
                $errors = $this->flattenErrors($user->getErrors());
                $this->set('errors', $errors);
            }
        }
        $this->set(compact('user', 'referer'));
    }

    public function verifyEmail(string $token)
    {
        try {
            $tokenData = User::decodeEmailVerificationToken($token);
            $user = $this->Users->get($tokenData->uid);
            $this->Authorization->authorize($user, 'edit');
            $user->updateEmailIfMatch($tokenData->val);
        } catch (RuntimeException $e) {
            $this->Authorization->skipAuthorization();
            $this->Flash->error($e->getMessage());

            return $this->redirect(['_name' => 'users:login']);
        }
        $this->Users->save($user);
        $this->Flash->success(__('Your email has been verified.'));
        $this->redirect(['_name' => 'tasks:today']);
    }

    public function resetPassword()
    {
        $this->Authorization->skipAuthorization();
        if ($this->request->is('post')) {
            $email = $this->request->getData('email');
            try {
                $user = $this->Users->findByEmail($email)->firstOrFail();
                $this->getMailer('Users')->send('resetPassword', [$user]);
            } catch (RecordNotFoundException $e) {
                // Do nothing.
            }
            $this->Flash->success(__('A password reset email has been sent if the email has a registered account.'));
        }
    }

    public function newPassword(string $token)
    {
        $this->set('token', $token);
        $this->Authorization->skipAuthorization();
        try {
            $tokenData = User::decodePasswordResetToken($token);
        } catch (RuntimeException $e) {
            $this->Flash->error($e->getMessage());

            return;
        }

        if ($this->request->is('post')) {
            $user = $this->Users->get($tokenData->uid);
            $user = $this->Users->patchEntity($user, $this->request->getData(), [
                'fields' => ['password', 'confirm_password'],
                'validate' => 'resetPassword',
            ]);

            if ($user->hasErrors()) {
                $this->Flash->error(__('We could not reset your password.'));
                $errors = $this->flattenErrors($user->getErrors());
                $this->set('errors', $errors);

                return;
            }

            $this->Users->save($user);
            $this->Flash->success(__('Your password has been reset.'));
            $this->redirect(['_name' => 'users:login']);
        }
    }

    public function login()
    {
        $this->Authorization->skipAuthorization();

        $this->request->allowMethod(['get', 'post']);
        $result = $this->Authentication->getResult();

        // regardless of POST or GET, redirect if user is logged in
        if ($result && $result->isValid()) {
            $redirect = $this->request->getQuery('redirect', ['_name' => 'tasks:today']);
            $identity = $this->request->getAttribute('identity');
            if ($this->request->getData('timezone')) {
                $identity = $this->Users->patchEntity($identity, $this->request->getData());
                $this->Users->save($identity);
            }

            if ($redirect) {
                return $this->redirect($redirect);
            }
        }

        // display error if user submitted and authentication failed
        if ($this->request->is('post') && !($result && $result->isValid())) {
            $this->Flash->error(__('Invalid username or password'));
        }
    }

    public function logout()
    {
        $this->Authorization->skipAuthorization();

        $this->Authentication->logout();

        return $this->redirect(['_name' => 'users:login']);
    }
}
