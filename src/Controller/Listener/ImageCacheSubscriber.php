<?php

namespace App\Controller\Listener;

use App\Entity\Property;
use Doctrine\Bundle\DoctrineBundle\Attribute\AsDoctrineListener;
use Doctrine\ORM\Event\PreRemoveEventArgs;
use Doctrine\ORM\Event\PreUpdateEventArgs;
use Doctrine\ORM\Events;
use Liip\ImagineBundle\Imagine\Cache\CacheManager;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Vich\UploaderBundle\Storage\StorageInterface;

#[AsDoctrineListener(event: Events::preRemove)]
#[AsDoctrineListener(event: Events::preUpdate)]
class ImageCacheSubscriber
{
    public function __construct(
        private readonly CacheManager $cacheManager,
        private readonly StorageInterface $storage,
    ) {
    }

    public function preRemove(PreRemoveEventArgs $args): void
    {
        $entity = $args->getObject();

        if (!$entity instanceof Property) {
            return;
        }

        $this->removeCachedImages($entity);
    }

    public function preUpdate(PreUpdateEventArgs $args): void
    {
        $entity = $args->getObject();

        if (!$entity instanceof Property) {
            return;
        }

        if ($entity->getImageFile() instanceof UploadedFile) {
            $this->removeCachedImages($entity);
        }
    }

    private function removeCachedImages(Property $property): void
    {
        $uri = $this->storage->resolveUri($property, 'imageFile');

        if ($uri) {
            $this->cacheManager->remove($uri);
        }
    }
}