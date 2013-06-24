requires "Authen::SASL" => "0";
requires "Email::AddressParser" => "0";
requires "Email::Stuffer" => "0";
requires "File::Slurp" => "0";
requires "Hash::Merge" => "0.12";
requires "IO::Socket::SSL" => "0";
requires "Net::SMTP::SSL" => "0";
requires "Net::SMTP::TLS" => "0";
requires "Net::SSLeay" => "0";

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.30";
};
