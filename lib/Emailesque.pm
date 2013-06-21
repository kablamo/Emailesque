# ABSTRACT: Lightweight To-The-Point Email

package Emailesque;

BEGIN {
    use Exporter();
    use vars qw( @ISA @EXPORT @EXPORT_OK );
    @ISA    = qw( Exporter );
    @EXPORT = qw(email);
}

use Hash::Merge;
use Email::Stuffer;
use Email::AddressParser;

sub new {
    my $class = shift;
    my $attributes = shift;

    $attributes->{driver} = 'sendmail' unless defined $attributes->{driver};

    return bless { settings => $attributes }, $class;
}

sub email {
    return Emailesque->new(@_)->send({});
}

sub send {
    my ($self, $options, @arguments)  = @_;
    my $stuff = Email::Stuff->new;
    my $settings = $self->{settings};

    $options = Hash::Merge->new( 'LEFT_PRECEDENT' )->merge($options, $settings);
    # requested by igor.bujna@post.cz

    die "cannot send mail without a sender, recipient, subject and message"
        unless $options->{to} && $options->{from} &&
               $options->{subject} && $options->{message};

    # process to
    if ($options->{to}) {
        $stuff->to(join ",",
            map { $_->format } Email::AddressParser->parse($options->{to}));
    }

    # process from
    if ($options->{from}) {
        $stuff->from(join ",",
            map { $_->format } Email::AddressParser->parse($options->{from}));
    }

    # process cc
    if ($options->{cc}) {
        $stuff->cc(join ",",
            map { $_->format } Email::AddressParser->parse($options->{cc}));
    }

    # process bcc
    if ($options->{bcc}) {
        $stuff->bcc(join ",",
            map { $_->format } Email::AddressParser->parse($options->{bcc}));
    }

    # process reply_to
    if ($options->{reply_to}) {
        $stuff->header("Return-Path" => $options->{reply_to});
    }

    # process subject
    if ($options->{subject}) {
        $stuff->subject($options->{subject});
    }

    # process message
    if ($options->{message}) {
        # multipart send using plain text and html
        if (lc($options->{type}) eq 'multi') {
            if (ref($options->{message}) eq "HASH") {
                $stuff->html_body($options->{message}->{html})
                    if defined $options->{message}->{html};
                $stuff->text_body($options->{message}->{text})
                    if defined $options->{message}->{text};
            }
        }
        else {
            # standard send using html or plain text
            if (lc($options->{type}) eq 'html') {
                $stuff->html_body($options->{message});
            }
            else {
                $stuff->text_body($options->{message});
            }
        }
    }

    # process additional headers
    if ($options->{headers} && ref($options->{headers}) eq "HASH") {
        foreach my $header (keys %{ $options->{headers} }) {
            $stuff->header( $header => $options->{headers}->{$header} );
        }
    }

    # process attachments
    if ($options->{attach}) {
        if (ref($options->{attach}) eq "ARRAY") {
            my %files = @{$options->{attach}};
            foreach my $file (keys %files) {
                $files{$file} ?
                    $stuff->attach($file, 'filename' => $files{$file}) :
                    $stuff->attach_file($file)
                ;
            }
        }
    }

    # some light error handling
    die 'Email error: specify type multi if sending text and html'
        if lc($options->{type}) eq 'multi' && "HASH" eq ref $options->{type}
    ;

    # okay, go team, go
    if (defined $settings->{driver}) {

        if (lc($settings->{driver}) eq lc("sendmail")) {
            $stuff->{send_using} = ['Sendmail', $settings->{path}];

            # failsafe
            $Email::Send::Sendmail::SENDMAIL = $settings->{path} if
                defined $settings->{path};
        }

        if (lc($settings->{driver}) eq lc("smtp")) {
            if ($settings->{host} && $settings->{user} && $settings->{pass}) {

                my @parameters = ();

                push @parameters, 'Host' => $settings->{host}
                    if $settings->{host};

                push @parameters, 'Port' => $settings->{port}
                    if $settings->{port};

                push @parameters, 'username' => $settings->{user}
                    if $settings->{user};

                push @parameters, 'password' => $settings->{pass}
                    if $settings->{pass};

                push @parameters, 'ssl' => $settings->{ssl}
                    if $settings->{ssl};

                 push @parameters, 'Debug' => 1
                    if $settings->{debug};

                push @parameters, 'Proto' => 'tcp';
                push @parameters, 'Reuse' => 1;

                $stuff->{send_using} = ['SMTP', @parameters];

            }
            else {
                $stuff->{send_using} = ['SMTP', Host => $settings->{host}];
            }
        }

        if (lc($settings->{driver}) eq lc("qmail")) {
            $stuff->{send_using} = ['Qmail', $settings->{path}];

            # fail safe
            $Email::Send::Qmail::QMAIL = $settings->{path} if
                defined $settings->{path};
        }

        if (lc($settings->{driver}) eq lc("nntp")) {
            $stuff->{send_using} = ['NNTP', $settings->{host}];
        }

        my $email = $stuff->email or return undef;

        # die Dumper $email->as_string;
        return $stuff->mailer->send( $email );

    }

    else {

        $stuff->using(@arguments) if @arguments; # Arguments passed to ->using

        my $email = $stuff->email or return undef;

        return $stuff->mailer->send( $email );

    }
};

=head1 SYNOPSIS

    use Emailesque;

    email {
        to      => '...',
        from    => '...',
        subject => '...',
        message => '...',
    };

=head1 DESCRIPTION

Emailesque provides an easy way of handling text or html email messages
with or without attachments. Simply define how you wish to send the email,
thencall the email keyword passing the necessary parameters as outlined above.
This module is basically a wrapper around the email interface Email::Stuffer.
The following is an example of the object-oriented interface:

    use Emailesque;

    Emailesque->new->send({
        to      => '...',
        from    => '...',
        subject => '...',
        message => '...',
        attach  => [
            '/path/to/file' => 'filename'
        ]
    });

The default email format is plain-text, this can be changed to html by setting
the option 'type' to 'html'. The following are options that can be passed within
the hashref of arguments to the keyword, constructor and/or the send method:

    # send message to
    to => $email_recipient

    # send messages from
    from => $mail_sender

    # email subject
    subject => 'email subject line'

    # message body
    message => 'html or plain-text data'
    message => {
        text => $text_message,
        html => $html_messase,
        # type must be 'multi'
    }

    # email message content type
    type => 'text'
    type => 'html'
    type => 'multi'

    # carbon-copy other email addresses
    cc => 'user@site.com'
    cc => 'user_a@site.com, user_b@site.com, user_c@site.com'
    cc => join ', ', @email_addresses

    # blind carbon-copy other email addresses
    bcc => 'user@site.com'
    bcc => 'user_a@site.com, user_b@site.com, user_c@site.com'
    bcc => join ', ', @email_addresses

    # specify where email responses should be directed
    reply_to => 'other_email@website.com'

    # attach files to the email
    # set attechment name to null to use the filename
    attach => [
        $file_location => $attachment_name,
    ]

    # send additional (specialized) headers
    headers => {
        "X-Mailer" => "SPAM-THE-WORLD-BOT 1.23456789"
    }

=head1 ADDITIONAL EXAMPLES

    # Handle Email Failures

    my $msg = email {
            to      => '...',
            subject => '...',
            message => $msg,
            attach  => [
                '/path/to/file' => 'filename'
            ]
        };

    die $msg unless $msg;

    # Add More Email Headers

    email {
        to      => '...',
        subject => '...',
        message => $msg,
        headers => {
            "X-Mailer" => 'SPAM-THE-WORLD-BOT 1.23456789',
            "X-Accept-Language" => 'en'
        }
    };

    # Send Text and HTML Email together

    email {
        to      => '...',
        subject => '...',
        type    => 'multi',
        message => {
            text => $txt,
            html => $html,
        }
    };

    # Send mail via SMTP with SASL authentication

    {
        ...,
        driver  => 'smtp',
        host    => 'smtp.googlemail.com',
        user    => 'account@gmail.com',
        pass    => '****'
    }

    # Send mail to/from Google (gmail)

    {
        ...,
        ssl     => 1,
        driver  => 'smtp',
        host    => 'smtp.googlemail.com',
        port    => 465,
        user    => 'account@gmail.com',
        pass    => '****'
    }

    # Send mail to/from Google (gmail) using TLS

    {
        ...,
        tls     => 1,
        driver  => 'smtp',
        host    => 'smtp.googlemail.com',
        port    => 587,
        user    => 'account@gmail.com',
        pass    => '****'
    }

    # Debug email server communications, prints negotiation to STDOUT

    {
        ...,
        debug => 1
    }

    # Set headers to be issued with message

    {
        ...,
        from => '...',
        subject => '...',
        headers => {
            'X-Mailer' => 'MyApp 1.0',
            'X-Accept-Language' => 'en'
        }
    }

    # Send email using sendmail, path is optional

    {
        ...,
        driver  => 'sendmail',
        path    => '/usr/bin/sendmail',
    }

=cut

1;
