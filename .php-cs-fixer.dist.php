<?php

$finder = (new PhpCsFixer\Finder())
    ->in(__DIR__)
    ->path(['custom/plugins/**', 'custom/apps/**'])
    ->exclude('var')
    ->exclude('docker')
;

return (new PhpCsFixer\Config())
    ->setRules([
        '@Symfony' => true,
    ])
    ->setFinder($finder)
;
