from core.handler import Handler
from core.utils import *
import linecache


class Xref(Handler):
    name = "_xref"
    no_message: str

    def process_request(self, position) -> dict:
        self.pos = position
        return dict(position=position)

    def process_response(self, response) -> None:
        if not response:
            message_emacs(self.no_message)
            return

        if not isinstance(response, list):
            response = [response]

        result = []
        for location in response:
            uri = location.get("targetUri", location["uri"])
            range = location.get("targetRange", location["range"])

            file = uri_to_path(uri)
            start = range["start"]
            end = range["end"]

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


class XrefFindDeclaration(Xref, Handler):
    name = "xref_find_declaration"
    method = "textDocument/declaration"
    no_message = "No declaration."


class XrefFindDefinition(Xref, Handler):
    name = "xref_find_definition"
    method = "textDocument/definition"
    no_message = "No definition."


class XrefFindTypeDefinition(Xref, Handler):
    name = "xref_find_type_definition"
    method = "textDocument/typeDefinition"
    no_message = "No type definition."


class XrefFindImplementation(Xref, Handler):
    name = "xref_find_implementation"
    method = "textDocument/implementation"
    no_message = "No implementation."


class XrefFindReferences(Xref, Handler):
    name = "xref_find_references"
    method = "textDocument/references"
    no_message = "No references."

    def process_request(self, position) -> dict:
        self.pos = position
        return dict(
            position=position,
            context=dict(includeDeclaration=False),
        )
