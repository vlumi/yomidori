#!/usr/bin/env python3
"""Convert manga-ocr to Core ML: the second opinion on a tapped line.

    Scripts/data/build-mangaocr.py [--output DIR]

manga-ocr (https://github.com/kha-white/manga-ocr, MIT) is a vision transformer
encoder with a small BERT decoder, trained to read one line or bubble of Japanese
at a time, vertical included. The encoder converts as it is; the decoder is
re-expressed here as one cache-free step, the BERT layers called directly with an
explicit float mask, because the library's own mask and embedding code casts in
ways the converter cannot take. The output is two .mlpackage bundles at half
precision (~210 MB together) and the vocabulary the decoder's ids map to, into
the app target; none of it is committed.

Needs Python 3.13 and the packages in mangaocr-requirements.txt; `make models`
sets that up in .build-data/ocr-venv. Run once per machine.
"""

import argparse
import os
import shutil
import sys

import numpy as np
import torch
import coremltools as ct
from huggingface_hub import hf_hub_download
from transformers import VisionEncoderDecoderModel

REPO = "kha-white/manga-ocr-base"
MAXLEN = 48  # tokens per line; a tapped window is far shorter
DEFAULT_OUTPUT = "Sources/Shared/Models"


class Encoder(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, pixels):
        return self.m(pixel_values=pixels).last_hidden_state


class DecoderStep(torch.nn.Module):
    """Logits for every position given the tokens so far (padded to MAXLEN) and the
    encoder's memory. Embeddings by hand on 32-bit indices with constant positions;
    an additive float mask, causal over the tokens so far with padding masked."""

    def __init__(self, d):
        super().__init__()
        self.emb, self.layers, self.head = d.bert.embeddings, d.bert.encoder.layer, d.cls
        self.register_buffer("positions", torch.arange(MAXLEN, dtype=torch.int32).reshape(1, MAXLEN))
        self.register_buffer("types", torch.zeros((1, MAXLEN), dtype=torch.int32))
        self.register_buffer("causal", torch.tril(torch.ones(MAXLEN, MAXLEN, dtype=torch.float32)))

    def forward(self, ids, mask, memory):
        h = (
            self.emb.word_embeddings(ids)
            + self.emb.position_embeddings(self.positions)
            + self.emb.token_type_embeddings(self.types)
        )
        h = self.emb.LayerNorm(h)
        allowed = self.causal * mask.reshape(1, MAXLEN)
        additive = ((1.0 - allowed) * -1e4).reshape(1, 1, MAXLEN, MAXLEN)
        for layer in self.layers:
            out = layer(h, attention_mask=additive, encoder_hidden_states=memory)
            h = out[0] if isinstance(out, tuple) else out
        return self.head(h)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    os.makedirs(args.output, exist_ok=True)

    model = VisionEncoderDecoderModel.from_pretrained(REPO, attn_implementation="eager").eval()
    common = dict(minimum_deployment_target=ct.target.iOS16, compute_precision=ct.precision.FLOAT16, convert_to="mlprogram")

    pixels = torch.zeros(1, 3, 224, 224)
    with torch.no_grad():
        traced = torch.jit.trace(Encoder(model.encoder), pixels, strict=False)
        memory = traced(pixels)
    encoder = ct.convert(traced, inputs=[ct.TensorType(name="pixels", shape=(1, 3, 224, 224))],
                         outputs=[ct.TensorType(name="memory")], **common)
    encoder.save(os.path.join(args.output, "MangaOCREncoder.mlpackage"))
    print("encoder converted; memory", tuple(memory.shape), file=sys.stderr)

    ids = torch.zeros((1, MAXLEN), dtype=torch.int32)
    ids[0, 0] = 2
    mask = torch.zeros((1, MAXLEN), dtype=torch.float32)
    mask[0, 0] = 1
    step = DecoderStep(model.decoder).eval()
    with torch.no_grad():
        reference = model.decoder(input_ids=ids.long()[:, :1], encoder_hidden_states=memory).logits[0, 0]
        ours = step(ids, mask, memory)[0, 0]
        assert torch.allclose(reference, ours, atol=1e-3), "the hand-written step disagrees with the library"
        traced = torch.jit.trace(step, (ids, mask, memory), strict=False)
    decoder = ct.convert(
        traced,
        inputs=[ct.TensorType(name="ids", shape=(1, MAXLEN), dtype=np.int32),
                ct.TensorType(name="mask", shape=(1, MAXLEN), dtype=np.float32),
                ct.TensorType(name="memory", shape=tuple(memory.shape))],
        outputs=[ct.TensorType(name="logits")], **common)
    decoder.save(os.path.join(args.output, "MangaOCRDecoder.mlpackage"))
    print("decoder converted", file=sys.stderr)

    shutil.copy(hf_hub_download(REPO, "vocab.txt"), os.path.join(args.output, "manga-ocr-vocab.txt"))
    total = sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(args.output) for f in fs) / 1e6
    print(f"wrote {args.output}: encoder, decoder step (MAXLEN {MAXLEN}), vocabulary; {total:.0f} MB")


if __name__ == "__main__":
    main()
