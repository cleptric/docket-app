<?php
declare(strict_types=1);

namespace App\Model\Table;

use Cake\ORM\Query;
use Cake\ORM\RulesChecker;
use Cake\ORM\Table;
use Cake\Validation\Validator;

/**
 * Projects Model
 *
 * @property \App\Model\Table\UsersTable&\Cake\ORM\Association\BelongsTo $Users
 * @property \App\Model\Table\TodoItemsTable&\Cake\ORM\Association\HasMany $TodoItems
 * @property \App\Model\Table\TodoLabelsTable&\Cake\ORM\Association\HasMany $TodoLabels
 *
 * @method \App\Model\Entity\Project newEmptyEntity()
 * @method \App\Model\Entity\Project newEntity(array $data, array $options = [])
 * @method \App\Model\Entity\Project[] newEntities(array $data, array $options = [])
 * @method \App\Model\Entity\Project get($primaryKey, $options = [])
 * @method \App\Model\Entity\Project findOrCreate($search, ?callable $callback = null, $options = [])
 * @method \App\Model\Entity\Project patchEntity(\Cake\Datasource\EntityInterface $entity, array $data, array $options = [])
 * @method \App\Model\Entity\Project[] patchEntities(iterable $entities, array $data, array $options = [])
 * @method \App\Model\Entity\Project|false save(\Cake\Datasource\EntityInterface $entity, $options = [])
 * @method \App\Model\Entity\Project saveOrFail(\Cake\Datasource\EntityInterface $entity, $options = [])
 * @method \App\Model\Entity\Project[]|\Cake\Datasource\ResultSetInterface|false saveMany(iterable $entities, $options = [])
 * @method \App\Model\Entity\Project[]|\Cake\Datasource\ResultSetInterface saveManyOrFail(iterable $entities, $options = [])
 * @method \App\Model\Entity\Project[]|\Cake\Datasource\ResultSetInterface|false deleteMany(iterable $entities, $options = [])
 * @method \App\Model\Entity\Project[]|\Cake\Datasource\ResultSetInterface deleteManyOrFail(iterable $entities, $options = [])
 *
 * @mixin \Cake\ORM\Behavior\TimestampBehavior
 */
class ProjectsTable extends Table
{
    /**
     * Initialize method
     *
     * @param array $config The configuration for the Table.
     * @return void
     */
    public function initialize(array $config): void
    {
        parent::initialize($config);

        $this->setTable('projects');
        $this->setDisplayField('name');
        $this->setPrimaryKey('id');

        $this->addBehavior('Timestamp');
        $this->addBehavior('Sluggable', [
            'label' => ['name'],
            'reserved' => ['archived', 'add', 'reorder'],
        ]);

        $this->belongsTo('Users', [
            'foreignKey' => 'user_id',
            'joinType' => 'INNER',
        ]);
        $this->hasMany('TodoItems', [
            'foreignKey' => 'project_id',
        ]);
        $this->hasMany('TodoLabels', [
            'foreignKey' => 'project_id',
        ]);
    }

    /**
     * Default validation rules.
     *
     * @param \Cake\Validation\Validator $validator Validator instance.
     * @return \Cake\Validation\Validator
     */
    public function validationDefault(Validator $validator): Validator
    {
        $validator
            ->integer('id')
            ->allowEmptyString('id', null, 'create');

        $validator
            ->scalar('name')
            ->maxLength('name', 255)
            ->requirePresence('name', 'create')
            ->notEmptyString('name');

        $validator
            ->scalar('color')
            ->maxLength('color', 6)
            ->requirePresence('color', 'create')
            ->notEmptyString('color')
            ->regex('color', '/^[a-f0-9]+$/', 'Must be a valid hex color code.');

        $validator
            ->boolean('favorite')
            ->notEmptyString('favorite');

        $validator
            ->boolean('archived')
            ->notEmptyString('archived');

        $validator
            ->integer('ranking')
            ->notEmptyString('ranking');

        return $validator;
    }

    /**
     * Returns a rules checker object that will be used for validating
     * application integrity.
     *
     * @param \Cake\ORM\RulesChecker $rules The rules object to be modified.
     * @return \Cake\ORM\RulesChecker
     */
    public function buildRules(RulesChecker $rules): RulesChecker
    {
        $rules->add($rules->existsIn(['user_id'], 'Users'), ['errorField' => 'user_id']);

        return $rules;
    }

    public function findTop(Query $query): Query
    {
        return $query
            ->orderAsc('Projects.ranking')
            ->orderDesc('Projects.name')
            ->limit(25);
    }

    public function findActive(Query $query): Query
    {
        return $query->where(['Projects.archived' => false]);
    }

    public function findArchived(Query $query): Query
    {
        return $query->where(['Projects.archived' => true]);
    }

    public function getNextRanking(int $userId): int
    {
        $query = $this->find();
        $query
            ->select(['count' => $query->func()->count('*')])
            ->where(['Projects.user_id' => $userId]);

        return (int)$query->firstOrFail()->count;
    }

    /**
     * Update the order on the list of projects
     *
     * @param \App\Model\Entity\Project[] $items
     * @return void
     */
    public function reorder(array $items)
    {
        $minValue = 0;
        $orderMap = [];
        foreach ($items as $i => $item) {
            if ($item->ranking < $minValue) {
                $minValue = $item->ranking;
            }
            $orderMap[$item->id] = $i;
        }
        $ids = array_keys($orderMap);

        $query = $this->query();
        $cases = $values = [];
        foreach ($orderMap as $id => $value) {
            $cases[] = $query->newExpr()->eq('id', $id);
            $values[] = $minValue + $value;
        }
        $case = $query->newExpr()
            ->addCase($cases, $values);
        $query
            ->update()
            ->set(['ranking' => $case])
            ->where(['id IN' => $ids]);
        $statement = $query->execute();

        return $statement->rowCount();
    }
}
