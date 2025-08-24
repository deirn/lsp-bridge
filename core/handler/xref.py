from core.handler import Handler
from core.utils import *
import linecache


class Xref(Handler):
    name = "_xref"
    cancel_on_change = True
    no_message: str

    def eval(self, results):
        eval_in_emacs("lsp-bridge-xref--callback", self.cmd, results, self.display_action)

    def process_request(self, arg, position, display_action, cmd) -> dict:
        self.arg = arg
        self.pos = position
        self.display_action = display_action
        self.cmd = cmd
        return dict(position=position)

    def process_response(self, response) -> None:
        if not response:
            message_emacs(self.no_message)
            return

        if not isinstance(response, list):
            response = [response]

        results = []
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

            result = dict(
                file=file,
                line=start_line,
                col=start_char,
                desc=desc,
            )

            if same_line:
                result["len"] = end_char - start_char

            results.append(result)

        linecache.clearcache()
        self.eval(results)


class XrefDeclarations(Xref, Handler):
    name = "xref_declarations"
    method = "textDocument/declaration"
    no_message = "No declaration."


class XrefDefinitions(Xref, Handler):
    name = "xref_definitions"
    method = "textDocument/definition"
    no_message = "No definition."


class XrefTypeDefinitions(Xref, Handler):
    name = "xref_type_definitions"
    method = "textDocument/typeDefinition"
    no_message = "No type definition."


class XrefImplementations(Xref, Handler):
    name = "xref_implementations"
    method = "textDocument/implementation"
    no_message = "No implementation."


class XrefReferences(Xref, Handler):
    name = "xref_references"
    method = "textDocument/references"
    no_message = "No references."

    def eval(self, results):
        if str(self.cmd) == "xref-find-references-and-replace":
            eval_in_emacs("lsp-bridge-xref--replace-callback", self.cmd, results, self.display_action)
        else:
            super().eval(results)

    def process_request(self, arg, position, display_action, cmd) -> dict:
        req = super().process_request(arg, position, display_action, cmd)
        req["context"] = dict(includeDeclaration=True)
        return req


class XrefApropos(Xref, Handler):
    name = "xref_apropos"
    method = "workspace/symbol"
    provider = "workspace_symbol_provider"
    provider_message = "Current server not support workspace symbol."
    no_message = "No matches."

    def process_request(self, arg, position, display_action, cmd) -> dict:
        super().process_request(arg, position, display_action, cmd)
        return dict(query=arg)

    def process_response(self, response) -> None:
        if isinstance(response, list):
            response = [x["location"] for x in response]
        super().process_response(response)  # pyright: ignore[reportArgumentType]
