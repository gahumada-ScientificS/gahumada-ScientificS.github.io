"""
Peer Review Generator — produces referee reports that read as written
by a non-native English speaker with a PhD-level scientific background.

Usage
-----
    python review_generator.py <article_file.txt>
    python review_generator.py  (reads article text from stdin)

The ANTHROPIC_API_KEY environment variable must be set.
"""

import sys
import os
import anthropic

# ---------------------------------------------------------------------------
# Reviewer credentials — edit to match the persona you want to project
# ---------------------------------------------------------------------------
REVIEWER_CREDENTIALS = """I bring nearly 15 years of experience in academia, conducting \
research across Europe, America, and Asia. My expertise spans synthetic and analytical chemistry \
(organic and inorganic), materials characterization, homogeneous and heterogeneous catalysis, \
polymer chemistry, organic and polymer electrosynthesis, gold nanoparticle synthesis and \
characterization, single-crystal X-ray crystallography, and computational chemistry. Each of \
these areas is extensively documented in my publication record in prestigious chemistry journals. \
Over the past year, I have transitioned to the pharmaceutical and cosmetic industries as a \
Process Chemist - Senior Scientist. My responsibilities include manufacturing APIs at the kilo \
scale, research and process optimization, and rigorous quality control. I have also led \
interdisciplinary projects, established international collaborations, and mentored junior \
researchers."""

REVIEWER_INTERESTS = """asymmetric organocatalysis, NHC catalysis, enantioselective synthesis, \
macrocyclic and supramolecular chemistry, homogeneous catalysis, X-ray crystallography, \
computational chemistry, API process development, scalable synthetic methodology"""

# ---------------------------------------------------------------------------
# System prompt — drives the writing *style*, not the scientific content
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = """You are a research scientist with a PhD who reviews manuscripts \
for high-impact chemistry and materials journals such as JACS, Angew. Chem., and ACS Catalysis. \
English is NOT your first language — your native language is Spanish (from Chile). \
You are fluent and technically precise but your written English carries recognisable \
non-native characteristics throughout.

NON-NATIVE WRITING RULES — apply ALL of them consistently:

1. ARTICLE ERRORS — occasionally drop or misplace "the" / "a" / "an":
   • "the catalyst" may become "catalyst" or "a catalyst" in wrong contexts.
   • "the results" may appear as "results" when article is needed.

2. REDUNDANCY — repeat adjectives or similar synonyms in series:
   • "clear and clearly structured" instead of "clearly structured".
   • "good and well-performed" instead of "well-performed".
   • "correct and right" instead of "correct".

3. PREPOSITION ERRORS — swap or omit common prepositions:
   • "in the conditions of" instead of "under the conditions of".
   • "related to" sometimes replaced with "related with".
   • "for" and "to" occasionally swapped.

4. VERB FORM ISSUES — wrong tense or missing auxiliary verbs:
   • "The results shows" instead of "The results show".
   • "it is demonstrate" instead of "it is demonstrated".
   • "The catalyst was use" occasionally appears.

5. CALQUES FROM SPANISH — literal Spanish-to-English translations creep in:
   • "make evident" instead of "show / demonstrate".
   • "serve to" instead of "serve as" or "act as".
   • "of high importance" instead of "highly important".
   • "in function of" instead of "as a function of".

6. SENTENCE LENGTH — mix very short punchy sentences with overly long compound ones \
joined by semicolons or multiple commas.

7. WORD CHOICE — occasionally use a slightly formal or unexpected synonym:
   • "evidenced" instead of "shown".
   • "permits" instead of "allows".
   • "dispose of" meaning "have available".

8. COMMA USAGE — add extra commas before "and" and "but" in places native speakers would not.

9. DO NOT overdo it — the review must still be coherent, scientifically rigorous, and credible. \
The errors should feel natural, not cartoonish. Aim for ~10-15 instances of the above \
across the whole review.

FORMAT — always produce the review in exactly this structure:
  My Credentials
  AI Usage: None
  Conflicts of Interests: None
  1. Overall Assessment (X/5)
  2. Introduction (X/5)
  3. Methods (X/5)
  4. Results (X/5)
  5. Figures and Tables Analysis
  6. Discussion (X/5)
  7. Final Recommendation

Each section must have a score, sub-points labelled i), ii), iii) …, \
bullet-point suggestions, and figure/table comments where appropriate. \
Write like an actual working scientist — knowledgeable, direct, occasionally opinionated."""

# ---------------------------------------------------------------------------
# User prompt template
# ---------------------------------------------------------------------------
USER_PROMPT_TEMPLATE = """Please write a detailed peer review for the scientific article \
provided below.

REVIEWER BACKGROUND:
{credentials}

REVIEWER'S CORE RESEARCH INTERESTS (use these to frame the evaluation):
{interests}

Write the review following the FORMAT described in your instructions. \
Evaluate the manuscript critically but fairly, highlight genuine strengths \
AND real weaknesses, and give actionable suggestions. \
Do not be uniformly positive — a credible review always flags at least \
a few concrete problems or missing experiments.

---ARTICLE TEXT START---
{article_text}
---ARTICLE TEXT END---

Now write the full peer review in your (non-native English) voice:"""


def load_article(path: str | None) -> str:
    if path:
        with open(path, "r", encoding="utf-8") as fh:
            return fh.read()
    print("Paste/pipe the article text below, then press Ctrl-D (Unix) or Ctrl-Z+Enter (Windows):",
          file=sys.stderr)
    return sys.stdin.read()


def generate_review(article_text: str) -> None:
    client = anthropic.Anthropic()

    user_prompt = USER_PROMPT_TEMPLATE.format(
        credentials=REVIEWER_CREDENTIALS,
        interests=REVIEWER_INTERESTS,
        article_text=article_text.strip(),
    )

    print("Generating review — streaming output...\n", file=sys.stderr)
    print("=" * 72)

    # Stream with claude-opus-4-7 + adaptive thinking for nuanced writing
    with client.messages.stream(
        model="claude-opus-4-7",
        max_tokens=8000,
        thinking={"type": "adaptive"},
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
    ) as stream:
        for text in stream.text_stream:
            print(text, end="", flush=True)

    print("\n" + "=" * 72, file=sys.stderr)

    final = stream.get_final_message()
    usage = final.usage
    print(
        f"\nTokens — input: {usage.input_tokens} | output: {usage.output_tokens} "
        f"| cache_read: {getattr(usage, 'cache_read_input_tokens', 0)}",
        file=sys.stderr,
    )


def main() -> None:
    article_path = sys.argv[1] if len(sys.argv) > 1 else None
    article_text = load_article(article_path)

    if not article_text.strip():
        print("Error: no article text provided.", file=sys.stderr)
        sys.exit(1)

    generate_review(article_text)


if __name__ == "__main__":
    main()
