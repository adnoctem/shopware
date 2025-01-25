server {
        listen ${PORT} default_server;
        listen [::]:${PORT} default_server;
        server_name ${HOSTNAME};

        root /var/www/html/public;
        index index.php;

        client_max_body_size 128M;

        location = /sitemap.xml {
            log_not_found off;
            access_log off;
            try_files $uri /;
        }

        location = /robots.txt {
            log_not_found off;
            access_log off;
            try_files $uri /;
        }

        # make status pages available locally or from within VPC/private network
        location ~ ^/-/fpm/(status|ping)$ {
            include fastcgi_params;
            allow 127.0.0.1;
            allow 172.16.0.0/12;
            allow 10.0.0.0/8;
            deny all;
            fastcgi_pass unix:${SOCKET_PATH};
        }

        # Deny access to . (dot) files
        location ~ /\. {
            deny all;
        }

        # Deny access to .php files in public directories
        location ~ ^/(theme|media|thumbnail|bundles|css|fonts|js|recovery|sitemap)/ {
            expires 1y;
            add_header Cache-Control "public, must-revalidate, proxy-revalidate";
            log_not_found off;
            tcp_nodelay off;
            open_file_cache max=3000 inactive=120s;
            open_file_cache_valid 45s;
            open_file_cache_min_uses 2;
            open_file_cache_errors off;

            location ~* ^.+\.svg {
                add_header Content-Security-Policy "script-src 'none'";
                add_header Cache-Control "public, must-revalidate, proxy-revalidate";
                log_not_found off;
            }
        }

        location ~* ^.+\.(?:css|cur|js|jpe?g|gif|ico|png|svg|webp|html|woff|woff2|xml)$ {
            expires 1y;
            add_header Cache-Control "public, must-revalidate, proxy-revalidate";
            access_log off;

            # The directive enables or disables messages in error_log about files not found on disk.
            log_not_found off;
            tcp_nodelay off;

            ## Set the OS file cache.
            open_file_cache max=3000 inactive=120s;
            open_file_cache_valid 45s;
            open_file_cache_min_uses 2;
            open_file_cache_errors off;

            try_files $uri /index.php$is_args$args;
        }

        location ~* ^.+\.svg$ {
            add_header Content-Security-Policy "script-src 'none'";
        }

        location / {
            try_files $uri /index.php$is_args$args;
        }

        location ~ \.php$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_index index.php;
            fastcgi_buffers 8 16k;
            fastcgi_buffer_size 32k;
            fastcgi_read_timeout 300s;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            proxy_connect_timeout 15s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;
            send_timeout 300s;
            client_body_buffer_size 128k;
            fastcgi_pass unix:${SOCKET_PATH};
        }
}
