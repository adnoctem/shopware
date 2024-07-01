# General Documentation

Some files have been created and/or updated to configure your new packages.
Please review, edit and commit them: these files are yours.

shopware/core instructions:

* Setup your repository:

1. Go to the project directory
2. Create your code repository with the git init command and push it to your favourite Git service

* Run Shopware locally:

1. Adjust the .env file to your database
2. Run ./bin/console system:install --basic-setup
3. Optional: If you use Symfony CLI start the webserver symfony server:start -d
4. The default credentials for administration are admin with password shopware

* Run Shopware with Docker & Symfony CLI:

1. Start the docker containers with docker compose up -d
2. Run symfony console system:install --basic-setup
3. Start the webserver symfony server:start -d
4. The default credentials for administration are admin with password shopware
5. Optional: Open the Mail catcher with symfony open:local:webmail

* Read the documentation at https://developer.shopware.com/

symfony/messenger instructions:

* You're ready to use the Messenger component. You can define your own message buses
  or start using the default one right now by injecting the message_bus service
  or type-hinting Symfony\Component\Messenger\MessageBusInterface in your code.

* To send messages to a transport and handle them asynchronously:

1. Uncomment the MESSENGER_TRANSPORT_DSN env var in .env
   and framework.messenger.transports.async in config/packages/messenger.yaml;
2. Route your message classes to the async transport in config/packages/messenger.yaml.

* Read the documentation at https://symfony.com/doc/current/messenger.html

symfony/mailer instructions:

* You're ready to send emails.

* If you want to send emails via a supported email provider, install
  the corresponding bridge.
  For instance, composer require mailgun-mailer for Mailgun.

* If you want to send emails asynchronously:

1. Install the messenger component by running composer require messenger;
2. Add 'Symfony\Component\Mailer\Messenger\SendEmailMessage': amqp to the
   config/packages/messenger.yaml file under framework.messenger.routing
   and replace amqp with your transport name of choice.

* Read the documentation at https://symfony.com/doc/master/mailer.html

No security vulnerability advisories found.

No security vulnerability advisories found.
