<?php

/** @noinspection PhpMultipleClassDeclarationsInspection */

declare(strict_types=1);

use Composer\Autoload\ClassLoader;
use Doctrine\DBAL\Connection;
use PHPUnit\Framework\Attributes\CoversClass;
use Shopware\Core\Kernel;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

#[CoversClass(Kernel::class)]
class KernelTest extends KernelTestCase
{
    /**
     * @throws PHPUnit\Framework\MockObject\Exception
     */
    public function testKernel(): void
    {
        $projectDirectory = dirname(__DIR__.'..');
        $pluginDirectory = $projectDirectory.'/custom/plugins';
        $vendorDirectory = $projectDirectory.'/vendor';
        $classLoader = new ClassLoader($vendorDirectory);
        $pluginLoader = new Shopware\Core\Framework\Plugin\KernelPluginLoader\ComposerPluginLoader($classLoader, $pluginDirectory);
        $connection = $this->createMock(Connection::class);

        $kernel = new Kernel('test', true, $pluginLoader, '', 'v6.6.6.1', $connection, $projectDirectory);

        static::assertInstanceOf(Kernel::class, $kernel);
        static::assertSame('test', $kernel->getEnvironment());
    }
}
