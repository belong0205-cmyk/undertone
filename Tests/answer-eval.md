# Answer evaluation — manual check for TESTER

46 common kitchen-interview questions with an ideal answer and what must (not) happen. The ideal answer is one good
version; other wording passes if it meets every rule below.

## Setup
1. Build and open the app. On the Hồ sơ page import `Tests/eval-profile.undertone-profile` (double-click it or use
   Import) and make "Minh Le" the active profile. It is an imaginary person; its menu has the same shape as real menus:
   Vietnamese set meals on a 2-week rotation (Monday–Saturday) plus a Western set menu by weekday, written in Vietnamese.
2. Start listening, then speak each question through the speakers from Terminal, for example:
   `say -v Karen "What do you have in your menu?"` (Karen is an Australian voice). For split questions (section E) run
   the two `say` commands with `sleep 2` between them.
3. Write down today's weekday before section A (questions 5 and 10 depend on it).

## Pass rules (every answer)
1. Answers the question that was asked, at the same scope: a general question gets a general answer (big picture +
   at most 2–3 examples), a specific question gets exactly that detail.
2. No invented facts: no day, date, week, time, number, price or name that was not asked for or is not in the profile /
   knowledge base. Missing personal facts use a placeholder in square brackets.
3. At most 25 words in 1–2 sentences; spoken as the user ("I", "my", "we"); never "You could say…".
4. Simple B1 English; Vietnamese dishes get simple English names.
5. The Vietnamese answer says the same thing in the first person ("tôi").
6. Questions that need no reply show no answer ("-" or the filler is skipped).

## A. Menu — general vs specific
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 1 | What do you have in your menu? | We cook Vietnamese set meals, like braised pork with eggs and sour fish soup, and a Western set menu too. It changes every day. | Must NOT name a day (the original bug). Both menus mentioned. |
| 2 | What kind of food do you cook? | I cook Vietnamese home-style meals, like braised fish and sour soup, and some Western dishes like lasagne. | No day, no prices. |
| 3 | Tell me about your menu. | We have Vietnamese set meals with rice, a main dish, soup and vegetables, and a Western set menu. Both change every day. | General only. |
| 4 | What does one meal come with? | Each Vietnamese meal comes with rice, dipping sauce and iced tea, plus a main dish, a stir-fry, soup, vegetables and dessert. | From the menu header, no invented sides. |
| 5 | What's on the menu today? | (Tuesday) Today the Western menu has beef stew in red wine with mashed potato. The Vietnamese meal changes every week. | Uses today's weekday from the Western menu (Mon lasagne, Tue beef stew, Wed salmon, Thu spaghetti bolognese, Fri fish and chips, Sat roast chicken). Must not pick a Vietnamese week. Sunday → "We are closed on Sunday." |
| 6 | What are you cooking on Friday? | On Friday we have fish and chips on the Western menu, and a Vietnamese meal like caramelised prawns or braised fish. | Friday only; Western Friday = fish and chips. |
| 7 | Do you have vegetarian options? | Yes, every Vietnamese set meal has a vegetarian dish, like tofu in tomato sauce. | Yes + one real example. |
| 8 | How often does your menu change? | Both menus change every day. The Vietnamese one repeats every two weeks, and the Western one repeats every week. | From the menu structure. |
| 9 | What's your signature dish? | My best dishes are braised pork with eggs and sour fish soup. | From "Signature dishes" only. |
| 10 | What do you serve on Sunday? | We are closed on Sunday. | Must not invent Sunday dishes. |
| 11 | Do you serve any Western food? | Yes, we have a Western set menu every day, like beef lasagne and fish and chips. | No day needed. |
| 12 | What soup do you make? | We make a different soup every day, like sour fish soup or pumpkin soup. | General, no day. |

## B. Questions about the user — exact scope
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 13 | What's your name? | My name is Minh Le. | — |
| 14 | How old are you? | I'm 28 years old. | Age from 12 March 1998 and today (28 until 12 March 2027). |
| 15 | Where do you work? | I'm a commis chef at Green Bowl Catering. We cook set lunches for offices. | No address. |
| 16 | What time do you start work? | I start at 6 am. | Start time only. |
| 17 | What are your working hours? | I work from 6 am to 2:30 pm. | Not the opening hours. |
| 18 | When is your kitchen open? | We serve lunch from 10:30 am to 2 pm, Monday to Saturday. | Opening hours, not the user's hours. |
| 19 | How many people work in your kitchen? | There are eight people in our kitchen. | Number; roles optional only if short. |
| 20 | Tell me about your day. | I check deliveries and fridge temperatures, prep meat and vegetables, then cook the braised dishes and soups for lunch. | 2–3 steps, no clock times needed. |
| 21 | What are your main responsibilities? | I cook the braised dishes, stir-fries and soups, and I check fridge temperatures and label food. | From the profile. |
| 22 | How long have you been working as a cook? | I have about three years of kitchen experience. | 3 years. |
| 23 | Do you have any certificates? | Yes, I have a Food Safety Supervisor certificate and a First Aid certificate. | Both, no invented ones. |
| 24 | What languages do you speak? | I speak Vietnamese and some English. | — |

## C. Missing personal facts → placeholder
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 25 | What are your hobbies? | In my free time I like [your hobby]. | Hobbies are empty: must not invent one. |
| 26 | What's your phone number? | My phone number is [your phone number]. | Must not invent digits. |
| 27 | Where do you live? | I live in [your suburb]. | Must not use the workplace. |

## D. Cookery knowledge (Certificate III)
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 28 | What temperature should the fridge be? | We keep the fridge at 5 °C or below. | Australian 5 °C, not 40 °F. |
| 29 | What is the temperature danger zone? | It's between 5 and 60 °C, so I keep cold food below 5 and hot food above 60. | 5–60 °C. |
| 30 | How do you cool down a big pot of soup? | I use shallow trays and an ice bath: 60 to 21 °C within two hours, then down to 5 °C within four more. | 2h/4h rule. |
| 31 | What core temperature do you cook chicken to? | I cook chicken to at least 75 °C in the thickest part. | 75 °C. |
| 32 | What's the difference between cleaning and sanitising? | Cleaning removes dirt and grease, and sanitising kills bacteria. I always clean first, then sanitise. | Order: clean → sanitise. |
| 33 | What is FIFO? | FIFO means first in, first out: we use older stock first and put new stock at the back. | — |
| 34 | What are the five mother sauces? | They are béchamel, velouté, espagnole, tomato sauce and hollandaise. | All five. |
| 35 | What is a brunoise? | Brunoise is a very small dice, about 2 mm, cut from julienne. | ~2 mm. |
| 36 | How do you stop cross-contamination? | I use colour-coded boards, keep raw meat below cooked food, and wash my hands and sanitise between tasks. | — |
| 37 | A customer has a nut allergy. What do you do? | I check every ingredient, clean the bench and tools, use separate equipment, and tell the chef and the server. | No "it's probably fine". |
| 38 | What is mise en place? | It means having everything ready before service: ingredients prepped, tools ready and my station set up. | — |
| 39 | How do you work out the food cost percentage? | I divide the food cost by the selling price without GST, then multiply by 100. | Ex-GST. |
| 40 | What do you use on a deep-fryer fire? | A wet chemical extinguisher or a fire blanket, never water. | Class F, no water. |

## E. Questions in pieces
| # | Pieces (about 2 s apart) | Ideal answer | Must / must not |
|---|---|---|---|
| 41 | "What do you usually…" + "cook on Fridays?" | On Fridays we cook fish and chips on the Western menu, and Vietnamese dishes like caramelised prawns. | Answers the joined question, once. |
| 42 | "How many people…" + "work in your kitchen?" | There are eight people in our kitchen. | Not an answer to the first piece alone. |
| 43 | "Do you usually cook?" + "At your restaurant?" | Yes, I cook every day at work, mostly Vietnamese braised dishes and soups. | One answer for both pieces. |

## F. No answer expected
| # | Utterance | Expected |
|---|---|---|
| 44 | Okay. | No answer (filler). |
| 45 | Yes, chef. | No answer (filler). |
| 46 | Let's get started with the interview. | "-" (a statement, no question). |

## Recording results
For each failed item note: question #, the app's answer, which pass rule failed. Send failures about scope or invented
facts to DATA (knowledge/guide), and failures about format, joining pieces or the "-" reply to BACK END (prompt code).
