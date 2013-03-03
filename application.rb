require 'sinatra'
require 'tempfile'
require 'date'

$opts = {
  certificate: 'Company client certificate',
  organization: 'Whitebox.io LLC',
  country: 'RU',
  province: 'Moscow',
  locality: 'Moscow'
}

$ssl = {
  days: 180,
  pass: 'y01_|s5Up3RseCr37CApW'
}

def clear_newlines( token )
  token.gsub( /[\s\t\n\r\0\x0B]/, '' )
end

def format_spkac( username, email, key )
  "SPKAC=#{clear_newlines( key )}" +
  "\nCN=#{username}" +
  "\nemailAddress=#{email}" +
  "\n0.OU=#{$opts[:certificate]} client certificate" +
  "\norganizationName=#{$opts[:organization]}" +
  "\ncountryName=#{$opts[:country]}" +
  "\nstateOrProvinceName=#{$opts[:province]}" +
  "\nlocalityName=#{$opts[:locality]}"
end

def save_spkac!( spkac_key )
  spkac_file = Tempfile.new(
    ['cert', '.spkac'],
    File.expand_path( './tmp/certificates' )
  )
  spkac_file.write( spkac_key )
  spkac_file.close
  spkac_file.path
end

def sign_spkac!( spkac_filename )
  certificate_filename =  File.dirname( spkac_filename ) +
                          File::SEPARATOR +
                          File.basename( spkac_filename, '.spkac' )

  sign_command =  "/usr/bin/env openssl " +
                  "ca " + #-config #{ssl[:conf_file]} 
                  "-days #{$ssl[:days]} " +
                  "-notext -batch " +
                  "-spkac #{spkac_filename} " +
                  "-out #{certificate_filename} " +
                  "-passin pass:'#{$ssl[:pass]}'"
  system( sign_command )
  certificate_filename
end

def respond_with_certificate( certificate )
  headers = {
    'Last-Modified' => Time.now.to_datetime.httpdate,
    'Accept-Ranges' => 'bytes',
    'Content-Length' => File.size( certificate ).to_s,
    'Content-Type' => 'application/x-x509-user-cert'
  }
  headers.each_pair do |k, v|
    response.headers[ k ] = v
  end
  File.read( certificate )
end

get '/' do
  erb :index
end

post '/submit' do
  key = params[ 'key' ]
  username = params[ 'username' ]
  email = params[ 'email' ]
  if key.nil?
    redirect '/'
  end
  spkac_key = format_spkac( username, email, key )
  spkac_filename = save_spkac!( spkac_key )
  signed_filename = sign_spkac!( spkac_filename )
  respond_with_certificate( signed_filename )
end