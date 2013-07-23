# ABSTRACT: Lightweight To-The-Point Email

package Emailesque;

BEGIN {
    use Exporter();
    use vars qw(@ISA @EXPORT @EXPORT_OK);
    @ISA    = qw( Exporter );
    @EXPORT = qw(email);
}

use File::Slurp;
use Hash::Merge;
use Email::AddressParser;
use Email::Sender::Transport::Sendmail;
use Email::Sender::Transport::SMTP;
use Email::Stuffer;

# VERSION

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
            'filename' => '/path/to/file'
        ]
    });

The Emailesque object-oriented interface is designed to accept parameters at
instatiation and when calling the send method. This allows you to build-up an
email object with a few base parameters, then create and send multiple email
messages by calling the send method with only the unique parameters. The
following is an example of that:

    use Emailesque;

    my $email = Emailesque->new({
        from    => '...',
        subject => '...',
        type    => 'html',
        headers => {
            "X-Mailer" => "MyApp-Newletter 0.019876"
        }
    });

    for my $email (@emails) {
        $email->send({
            to      => $email,
            message => custom_email_message_for($email),
        });
    }

The default email format is plain-text, this can be changed to html by setting
the option 'type' to 'html'. The following are options that can be passed within
the hashref of arguments to the keyword, constructor and/or the send method:

    # send message to
    to => $email_recipient

    # send messages from
    from => $mail_sender

    # email subject
    subject => 'email subject line'

    # message body (must set type to multi)
    message => 'html or plain-text data'
    message => {
        text => $text_message,
        html => $html_messase,
    }

    # email message content type
    type => 'text'
    type => 'html'
    type => 'multi'

    # carbon-copy other email addresses
    cc => 'user@site.com'
    cc => 'user_a@site.com, user_b@site.com, user_c@site.com'

    # blind carbon-copy other email addresses
    bcc => 'user@site.com'
    bcc => 'user_a@site.com, user_b@site.com, user_c@site.com'

    # specify where email responses should be directed
    reply_to => 'other_email@website.com'

    # attach files to the email
    # set attechment name to undef to use the filename
    attach => [
        $filepath => $filename,
    ]

    # send additional (specialized) headers
    headers => {
        "X-Mailer" => "SPAM-THE-WORLD-BOT 1.23456789"
    }

=head1 ADDITIONAL EXAMPLES

    # Handle Email Failures

    my $result = email {
            to      => '...',
            subject => '...',
            message => $msg,
            attach  => [
                '/path/to/file' => 'filename'
            ]
        };

    die $result->message if ref($result) =~ /failure/i;

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

sub new {
    my $class = shift;
    my $attributes = shift || {};

    $attributes->{driver} = 'sendmail' unless defined $attributes->{driver};
    $attributes->{type}   = 'html' unless defined $attributes->{type};

    return bless { settings => $attributes }, $class;
}

sub email {
    return Emailesque->new->send(@_);
}

sub send {
    my $self = shift;
    my $stuff = $self->_prepare_send(@_);

    return $stuff->send;
}

sub _prepare_send {
    my ($self, $options, @arguments)  = @_;
    my $stuff = Email::Stuffer->new;
    my $settings = $self->{settings};

    $settings = {} unless 'HASH' eq ref $settings;
    $options  = {} unless 'HASH' eq ref $options;

    $options = Hash::Merge->new( 'LEFT_PRECEDENT' )->merge($options, $settings);

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
                if ($files{$file}) {
                    my $data = read_file($files{$file}, binmode => ':raw');
                    $stuff->attach($data, name => $file, filename => $file);
                }
                else {
                  $stuff->attach_file($file);
                }
            }
        }
    }

    # check multi-type email messages
    if (lc($options->{type}) eq 'multi') {
        die 'Email error: specify type multi if sending text and html'
            unless "HASH" eq ref $options->{message}
                && exists $options->{message}->{text}
                && exists $options->{message}->{html};
    }

    # okay, go team, go
    if (!@arguments) {
        if (lc($options->{driver}) eq lc("sendmail")) {
            unless ($options->{path}) {
                for ('/usr/bin/sendmail', '/usr/sbin/sendmail') {
                    $options->{path} = $_ if -f $_
                }
            }

            $options->{path} ||= '';
            $stuff->transport('Sendmail' => (sendmail => $options->{path}));
        }

        if (lc($options->{driver}) eq lc("smtp")) {
            if ($options->{host} && $options->{user} && $options->{pass}) {
                my @parameters = ();

                push @parameters, 'host' => $options->{host}
                    if $options->{host};

                push @parameters, 'port' => $options->{port}
                    if $options->{port};

                push @parameters, 'sasl_username' => $options->{user}
                    if $options->{user};

                push @parameters, 'sasl_password' => $options->{pass}
                    if $options->{pass};

                push @parameters, 'ssl' => $options->{ssl}
                    if $options->{ssl};

                push @parameters, 'proto' => 'tcp'; # no longer used
                push @parameters, 'reuse' => 1;     # no longer used

                $stuff->transport('SMTP' => @parameters);
            }
            else {
                $stuff->transport('SMTP' => (host => $options->{host}));
            }
        }
    }

    else {
        $stuff->transport(@arguments) if @arguments;
    }

    return $stuff;
}

1;
