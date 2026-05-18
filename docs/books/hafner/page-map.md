# Page map — Terraform in Depth (Hafner, 2025)

PDF-to-print offset: **+28**  (PDF page 31 = printed page 3; PDF page 32 = printed page 4, etc.)

Total PDF pages: 505

| Chapter | Title | PDF start | PDF end | Printed start |
| --- | --- | --- | --- | --- |
| 1 | A brief overview of Terraform | 31 | 51 | 3 |
| 2 | Terraform HCL components | 52 | 87 | 24 |
| 3 | Terraform variables and modules | 88 | 115 | 60 |
| 4 | Expressions and iterations | 116 | 150 | 88 |
| 5 | The Terraform plan | 151 | 192 | 123 |
| — | *Part 2 opener* | 193 | 194 | 165 |
| 6 | State management | 195 | 234 | 167 |
| 7 | Code quality and continuous integration | 235 | 277 | 207 |
| 8 | Continuous delivery and deployment | 278 | 315 | 250 |
| 9 | Testing and refactoring | 316 | 362 | 288 |
| — | *Part 3 opener* | 363 | 364 | 335 |
| 10 | Advanced Terraform topics | 365 | 410 | 337 |
| 11 | Alternative interfaces | 411 | 453 | 383 |
| 12 | Terraform providers | 454 | 505 | 426 |

## Extraction command (per chapter)

```bash
pdftotext -f <PDF start> -l <PDF end> -layout \
  "Terraform in Depth_ Infrastructure as Code with Terraform and OpenTofu.pdf" \
  "docs/books/hafner/pdf-cache/<NN>-<slug>.txt"
```
