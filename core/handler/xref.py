from core.handler import Handler
from core.utils import *
from .jdt_uri_resolver import resolve_jdt_uri
import linecache


class Xref(Handler):
    name = "_xref"
    cancel_on_change = True
    no_message: str

    def process_request(self, arg, position, display_action, cmd):
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
        def resolve_callback(index, uri):
            if uri:
                location = response[index]
                file = uri_to_path(uri)
                range = location.get("targetRange", location["range"])
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

            if index < (len(response) - 1):
                resolve(index + 1)
            else:
                linecache.clearcache()
                eval_in_emacs(
                    "lsp-bridge-xref--callback",
                    results,
                    self.display_action,
                    self.cmd,
                )

        def resolve(index):
            location = response[index]
            uri = location.get("targetUri", location["uri"])

            if uri.startswith("jdt://"):
                self.file_action.send_server_request(
                    self.file_action.single_server,
                    "xref_jdt_uri_resolver",
                    uri,
                    lambda uri: resolve_callback(index, uri),
                )
            else:
                resolve_callback(index, uri)

        resolve(0)


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


class XrefJdtUriResolver(Handler):
    name = "xref_jdt_uri_resolver"
    method = "java/classFileContents"
    cancel_on_change = True
    send_document_uri = False

    def process_request(self, uri, callback) -> dict:
        self.uri = uri
        self.callback = callback
        return dict(uri=uri)

    def process_response(self, response):
        if (not response) or (not isinstance(response, str)):
            self.callback(None)
            return

        self.callback(resolve_jdt_uri(self.file_action, self.uri, response))
