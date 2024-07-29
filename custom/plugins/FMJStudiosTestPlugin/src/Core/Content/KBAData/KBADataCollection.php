<?php

declare(strict_types=1);

namespace FMJStudiosTestPlugin\Core\Content\KBAData;

use Shopware\Core\Framework\DataAbstractionLayer\EntityCollection;

/**
 * @method void add(KBADataEntity $entity)
 * @method void set(string $key, KBADataEntity $entity)
 * @method KBADataEntity[] getIterator()
 * @method KBADataEntity[] getElements()
 * @method KBADataEntity|null get(string $key)
 * @method KBADataEntity|null first()
 * @method KBADataEntity|null last()
 */
class KBADataCollection extends EntityCollection
{
    protected function getExpectedClass(): string
    {
        return KBADataEntity::class;
    }
}
