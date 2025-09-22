import hashlib
import os
import tempfile
from urllib.parse import urlparse, unquote

from core.handler import Handler
from core.utils import *


def resolve_jdt_uri(file_action, external_file_link, response):
    # Save the analysis content to the file.

    external_file_dir = ''
    decompile_dir_name = 'jdt-uri-resolver'

    try:
        # Value for -data: An absolute path to your data directory. eclipse.jdt.ls stores workspace specific information in it. This should be unique per workspace/project.
        index = file_action.single_server_info['command'].index('-data')
        data_dir = pathlib.Path(file_action.single_server_info['command'][index + 1])
    except:
        md5 = hashlib.md5()
        md5.update(file_action.get_lsp_server_project_path())
        project_hash = md5.hexdigest()
        data_dir = pathlib.Path(os.path.join(tempfile.gettempdir(), "lsp-bridge-jdtls", project_hash))

    external_file_dir = data_dir / decompile_dir_name

    url = urlparse(external_file_link)
    path = unquote(url.path).replace(".class", ".java")[1:]
    external_file = external_file_dir / path

    external_file.parent.mkdir(exist_ok=True, parents=True)

    if not external_file.exists():
        with open(external_file, 'w') as f:
            f.write(response)

    external_file = external_file.as_posix()
    file_action.create_external_file_action(external_file, external_file_link)
    return external_file


class JDTUriResolver(Handler):
    name = "jdt_uri_resolver"
    method = "java/classFileContents"
    cancel_on_change = True
    send_document_uri = False

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.external_file_link = None
        self.start_pos = None

    def process_request(self, uri, start_pos, define_jump_handler) -> dict:
        self.start_pos = start_pos
        self.external_file_link = uri
        self.define_jump_handler = define_jump_handler
        return dict(uri=uri)

    def process_response(self, response: str):
        if not response:
            message_emacs("No definition found.")
            return

        if isinstance(response, str):
            external_file = resolve_jdt_uri(self.file_action, self.external_file_link, response)
            eval_in_emacs(self.define_jump_handler, external_file, get_lsp_file_host(), self.start_pos)
