
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Lightweight To-The-Point Email",
  "AUTHOR" => "Al Newkirk <anewkirk\@ana.io>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Emailesque",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Emailesque",
  "PREREQ_PM" => {
    "Authen::SASL" => 0,
    "Email::AddressParser" => 0,
    "Email::Stuffer" => 0,
    "File::Slurp" => 0,
    "Hash::Merge" => "0.12",
    "IO::Socket::SSL" => 0,
    "Net::SMTP::SSL" => 0,
    "Net::SMTP::TLS" => 0,
    "Net::SSLeay" => 0
  },
  "TEST_REQUIRES" => {},
  "VERSION" => "1.200005",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



