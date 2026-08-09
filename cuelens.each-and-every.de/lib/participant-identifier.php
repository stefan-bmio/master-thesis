<?php
declare(strict_types=1);

final class ParticipantIdentifier
{
    public const DIRECT = 'DIRECT';
    public const PROLIFIC = 'PROLIFIC';

    private function __construct(
        private readonly string $channel,
        private readonly string $value
    ) {
    }

    public static function parse(string $input): self
    {
        $value = trim($input);
        if (preg_match('/^[A-Za-z0-9]{24}$/D', $value) === 1) {
            return new self(self::PROLIFIC, $value);
        }
        if ($value !== '' && filter_var($value, FILTER_VALIDATE_EMAIL) !== false) {
            return new self(self::DIRECT, $value);
        }

        throw new InvalidArgumentException('Invalid participant identifier.');
    }

    public function channel(): string
    {
        return $this->channel;
    }

    public function value(): string
    {
        return $this->value;
    }

    public function activationValue(): string
    {
        return $this->channel === self::DIRECT ? strtolower($this->value) : $this->value;
    }

    public function email(): ?string
    {
        return $this->channel === self::DIRECT ? $this->value : null;
    }

    public function prolificId(): ?string
    {
        return $this->channel === self::PROLIFIC ? $this->value : null;
    }
}
