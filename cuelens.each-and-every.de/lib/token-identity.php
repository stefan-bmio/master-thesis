<?php
declare(strict_types=1);

function valid_app_token_hash(string $secret, string $appToken): string
{
    return domain_separated_app_token_hash($secret, 'valid-token:v1', $appToken);
}

function participant_id_for_app_token(string $secret, string $appToken): string
{
    return domain_separated_app_token_hash($secret, 'pseudonym:v1', $appToken);
}

function registration_token_hash(string $secret, string $appToken): string
{
    return domain_separated_app_token_hash($secret, 'registration-token:v1', $appToken);
}

function domain_separated_app_token_hash(
    string $secret,
    string $context,
    string $appToken
): string {
    if ($secret === '') {
        throw new RuntimeException('Missing pseudonym secret.');
    }

    return hash_hmac('sha256', $context . "\0" . strtolower($appToken), $secret);
}
