# Page map — Terraform: Up & Running (Brikman, O'Reilly, 3rd ed. 2022)

PDF-to-print offset: **+26** (PDF page 27 = printed page 1)

| Chapter | Title | PDF start | PDF end | Printed pages |
| --- | --- | --- | --- | --- |
| 1 | Why Terraform | 27 | 64 | 1–38 |
| 2 | Getting Started with Terraform | 65 | 106 | 39–80 |
| 3 | How to Manage Terraform State | 107 | 140 | 81–114 |
| 4 | How to Create Reusable Infrastructure with Terraform Modules | 141 | 166 | 115–140 |
| 5 | Terraform Tips and Tricks: Loops, If-Statements, Deployment, and Gotchas | 167 | 216 | 141–190 |
| 6 | Managing Secrets with Terraform | 217 | 246 | 191–220 |
| 7 | Working with Multiple Providers | 247 | 300 | 221–274 |
| 8 | Production-Grade Terraform Code | 301 | 340 | 275–314 |
| 9 | How to Test Terraform Code | 341 | 400 | 315–374 |
| 10 | How to Use Terraform as a Team | 401 | ~444 | 375–~418 |

Index begins around PDF 446.

## How this was derived

1. TOC read from PDF pages 5–12 gives printed chapter start pages: 1, 39, 81, 115, 141, 191, 221, 275, 315, 375.
2. Offset confirmed by locating the Chapter 1 opening page at PDF 27, and re-confirmed at Chapter 4 (PDF 141) and Chapter 5 (PDF 167).
3. Each chapter's end is the page before the next chapter's start.

Extract a chapter with:

```bash
pdftotext -f <start> -l <end> -layout ../books/TUR.pdf docs/books/tur/pdf-cache/<NN>-<slug>.txt
```
