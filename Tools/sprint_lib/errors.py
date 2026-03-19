class SprintToolError(Exception):
    exit_code: int = 1

    def __init__(self, message: str):
        super().__init__(message)


class ItemNotFoundError(SprintToolError):
    exit_code = 1


class InvalidTransitionError(SprintToolError):
    exit_code = 2


class SetupError(SprintToolError):
    exit_code = 3


class ParseError(SprintToolError):
    exit_code = 1
