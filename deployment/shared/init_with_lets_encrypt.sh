#!/usr/bin/env bash

# Set up env variables associated with let's encrypt and domain
export $(grep -E '^(LETS_ENCRYPT_|VIRTUAL_HOST).*' settings.env | xargs);
rsa_key_size=4096
lets_encrypt="/etc/letsencrypt"

# Ask for new certificate only when previous was wiped. Also, if at least one of them is missing ask for a new one.
if [ $(/usr/local/bin/docker-compose run --rm --entrypoint "/bin/sh -c \"\
        [ ! -f $lets_encrypt/live/$VIRTUAL_HOST/privkey.pem -o\
          ! -f $lets_encrypt/live/$VIRTUAL_HOST/fullchain.pem ] && echo 1\"" service-configuration) ];
then
    # Openssl can have problems with creating files in non-existing path
    /usr/local/bin/docker-compose run --rm --entrypoint "mkdir -p '$lets_encrypt/live/$VIRTUAL_HOST'" service-configuration
    # Nginx won't start without a certificate.
    /usr/local/bin/docker-compose run --rm --entrypoint "\
      openssl req -x509 -nodes -newkey rsa:1024 -days 1\
        -keyout '$lets_encrypt/live/$VIRTUAL_HOST/privkey.pem' \
        -out '$lets_encrypt/live/$VIRTUAL_HOST/fullchain.pem' \
        -subj '/CN=localhost'" service-configuration
    /usr/local/bin/docker-compose up --force-recreate -d nginx-tls

    # Wait for nginx
    while ! (http_code=$(curl -w %{http_code} -s -o /dev/null http://$VIRTUAL_HOST) && ([ "$http_code" == "200" ] || [ "$http_code" == "301" ] || [ "$http_code" == "401" ])); do sleep 1; done
    echo "Nginx-tls is ready for Let's Encrypt challenge"

    # Certbot certonly won't create new certificate if a catalog wtih the domain name already exists (even empty).
    /usr/local/bin/docker-compose run --rm --entrypoint "\
      rm -Rf $lets_encrypt/live/$VIRTUAL_HOST && \
      rm -Rf $lets_encrypt/archive/$VIRTUAL_HOST && \
      rm -Rf $lets_encrypt/renewal/$VIRTUAL_HOST.conf" service-configuration

    case "$LETS_ENCRYPT_EMAIL" in
      "") email_arg="--register-unsafely-without-email" ;;
      *) email_arg="--email $LETS_ENCRYPT_EMAIL --no-eff-email" ;;
    esac
    if [ $LETS_ENCRYPT_DEBUG != "0" ]; then staging_arg="--staging"; fi

    /usr/local/bin/docker-compose run --rm --entrypoint "\
      certbot certonly --webroot -w /var/www/certbot/ \
        $staging_arg \
        $email_arg \
        -d $VIRTUAL_HOST\
        --rsa-key-size $rsa_key_size \
        --agree-tos \
        --force-renewal" service-configuration

    echo "Applying the newly generated certificates..."
    docker exec -it nginx-tls nginx -s reload
else
    echo "Using already existing certs"
fi;
