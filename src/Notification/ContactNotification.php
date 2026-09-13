<?php

namespace App\Notification;

use App\Entity\Contact;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Address;
use Symfony\Component\Mime\Email;
use Twig\Environment;

class ContactNotification
{
    public function __construct(
        private readonly MailerInterface $mailer,
        private readonly Environment $renderer,
    ) {
    }

    public function notify(Contact $contact): void
    {
        $message = (new Email())
            ->from(new Address('noreply@agence.com', 'Mon Agence'))
            ->to('contact@agence.com')
            ->replyTo($contact->getEmail())
            ->subject('Agence : '.((string) $contact->getProperty()?->getTitle()))
            ->html($this->renderer->render('emails/contact.html.twig', [
                'contact' => $contact,
            ]));

        $this->mailer->send($message);
    }
}