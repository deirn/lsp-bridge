from core.handler import Handler
from core.utils import *
import linecache


class XrefFindReferences(Handler):
    name = "xref_find_references"
    method = "textDocument/references"

    def process_request(self, position) -> dict:
        self.pos = position
        return dict(
            position=position,
            context=dict(includeDeclaration=False),
        )

    def process_response(self, response) -> None:
        if not response:
            message_emacs("No references.")
            return

        result = []
        for location in response:
            file = uri_to_path(location["uri"])
            start = location["range"]["start"]
            end = location["range"]["end"]

            start_line = start["line"] + 1
            start_char = start["character"]
            end_line = end["line"] + 1
            end_char = end["character"]
            same_line = start_line == end_line

            content = linecache.getline(file, start_line)
            desc = [
                content[0:start_char].lstrip(),
                content[start_char : end_char if same_line else len(content)],
                content[end_char:].rstrip() if same_line else "",
            ]

            result.append(
                dict(
                    file=file,
                    line=start_line,
                    col=start_char,
                    desc=desc,
                )
            )

        linecache.clearcache()
        eval_in_emacs("lsp-bridge-xref--callback", result)
