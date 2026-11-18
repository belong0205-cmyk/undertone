# Answer evaluation — manual check for TESTER

63 common kitchen-interview and assessment questions (including follow-ups) with an ideal answer and what must (not) happen. The ideal answer is one good
version; other wording passes if it meets every rule below.

## Setup
1. Build and open the app. On the Hồ sơ page import `Tests/eval-profile.undertone-profile` (double-click it or use
   Import) and make "Minh Le" the active profile. It is an imaginary person; its menu has the same shape as real menus:
   Vietnamese set meals on a 2-week rotation (Monday–Saturday) plus a European set menu by weekday, written in Vietnamese.
2. Start listening, then speak each question through the speakers from Terminal, for example:
   `say -v Karen "What do you have in your menu?"` (Karen is an Australian voice). For split questions (section E) run
   the two `say` commands with `sleep 2` between them.
3. Write down today's weekday before section A (questions 5 and 10 depend on it).

## Pass rules (every answer)
1. Answers the question that was asked, at the same scope: a general question gets a general answer (big picture +
   at most 2–3 examples), a specific question gets exactly that detail.
2. No invented facts: no day, date, week, time, number, price or name that was not asked for or is not in the profile /
   knowledge base. Missing personal facts use a placeholder in square brackets.
3. At most 25 words in 1–2 sentences (a follow-up in section H: 3–6 short sentences); spoken as the user ("I", "my", "we"); never "You could say…".
4. Simple B1 English; Vietnamese dishes get simple English names.
5. Menu and dish answers name European dishes first; Vietnamese dishes come after, or only when asked (user preference).
6. The Vietnamese answer says the same thing in the first person ("tôi").
7. Questions that need no reply show no answer ("-" or the filler is skipped).

## A. Menu — general vs specific
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 1 | What do you have in your menu? | We cook a European set menu, like lasagne and roast chicken, and Vietnamese set meals too. It changes every day. | Must NOT name a day (the original bug). European dishes first. |
| 2 | What kind of food do you cook? | I cook European dishes like lasagne and fish and chips, and also Vietnamese home-style meals. | European first; no day, no prices. |
| 3 | Tell me about your menu. | We have a European set menu with soup, a main, sides, salad and dessert, and Vietnamese set meals too. Both change every day. | General only; European first. |
| 4 | What does one meal come with? | Our European set menu comes with soup, a main course, a side, a salad and a dessert. | From the European menu header first; no invented sides. Vietnamese details only if asked. |
| 5 | What's on the menu today? | (Tuesday) Today the European menu has beef stew in red wine with mashed potato. The Vietnamese meal changes every week. | Uses today's weekday from the European menu, named first (Mon lasagne, Tue beef stew, Wed salmon, Thu spaghetti bolognese, Fri fish and chips, Sat roast chicken). Must not pick a Vietnamese week. Sunday → "We are closed on Sunday." |
| 6 | What are you cooking on Friday? | On Friday we have fish and chips on the European menu, and a Vietnamese meal like caramelised prawns. | Friday only; European Friday = fish and chips, named first. |
| 7 | Do you have vegetarian options? | Yes, every Vietnamese set meal has a vegetarian dish, like tofu in tomato sauce. | Yes + one real example. |
| 8 | How often does your menu change? | Both menus change every day. The European one repeats every week, and the Vietnamese one every two weeks. | From the menu structure; European first. |
| 9 | What's your signature dish? | My best dishes are braised pork with eggs and sour fish soup. | From "Signature dishes" only — stays Vietnamese because the profile says so. |
| 10 | What do you serve on Sunday? | We are closed on Sunday. | Must not invent Sunday dishes. |
| 11 | Do you serve any European food? | Yes, we have a European set menu every day, like beef lasagne and fish and chips. | No day needed. |
| 12 | What soup do you make? | We make a different soup every day, like pumpkin soup or mushroom soup, and Vietnamese sour fish soup. | General, no day; European soups first. |

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
| 21 | What are your main responsibilities? | I cook the European soups and mains and the Vietnamese braised dishes, and I check fridge temperatures. | From the profile; European first. |
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
| 41 | "What do you usually…" + "cook on Fridays?" | On Fridays we cook fish and chips on the European menu, and Vietnamese dishes like caramelised prawns. | Answers the joined question, once; European first. |
| 42 | "How many people…" + "work in your kitchen?" | There are eight people in our kitchen. | Not an answer to the first piece alone. |
| 43 | "Do you usually cook?" + "At your restaurant?" | Yes, I cook every day at work, European soups and mains, and Vietnamese braised dishes. | One answer for both pieces; European first. |

## F. No answer expected
| # | Utterance | Expected |
|---|---|---|
| 44 | Okay. | No answer (filler). |
| 45 | Yes, chef. | No answer (filler). |
| 46 | Let's get started with the interview. | "-" (a statement, no question). |

## G. Define / Explain / List (assessor style)
Answers must stay within 25 words, so they give the definition and the key numbers, not a full lesson.
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 47 | Define ganache and provide common ratios for dark vs milk/white chocolate. | Ganache is chocolate melted with hot cream. For a glaze I use 1:1 dark, 2:1 milk and 3:1 white chocolate to cream. | Definition + ratios for all three; milk and white need more chocolate than dark. Accept truffle ratios (2:1 dark, 2.5–3:1 milk, 3–4:1 white) if the use is named. |
| 48 | What is an emulsion? Give an example. | An emulsion is oil and water mixed into tiny drops, like mayonnaise or a vinaigrette. | Definition + example. |
| 49 | Explain the three types of roux. | All are equal flour and butter: white roux has no colour, blond is light golden, and brown is nut brown. | Equal weights; white / blond / brown. |
| 50 | List the five mother sauces. | Béchamel, velouté, espagnole, tomato sauce and hollandaise. | Names only, all five. |
| 51 | How do you temper dark chocolate? | I melt it to 45–50 °C, cool it to 27–28 °C, then warm it to 31–32 °C. | Three temperatures. |
| 52 | What is a liaison? | A liaison is egg yolks and cream added at the end to thicken a sauce or soup. I never boil it after. | No boiling. |
| 53 | What's the difference between braising and stewing? | Braising cooks large pieces in a little liquid; stewing cooks small pieces fully covered in liquid. Both are slow. | One clause each. |
| 54 | Name the three types of meringue. | French, Swiss and Italian meringue. | Names only. |
| 55 | What is the difference between crème anglaise and crème pâtissière? | Crème anglaise is a thin pouring custard I never boil; crème pâtissière is thick, with flour, and must boil. | Anglaise no boil; pâtissière boiled. |
| 56 | What does HACCP stand for? | Hazard Analysis and Critical Control Points. It's a system to control food safety hazards at key steps. | Full name correct. |

## H. Follow-up — more detail (within about 10 s)
Ask the first question, wait for its short answer, then ask the follow-up within 10 s, e.g.
`say -v Karen "What is a roux?"; sleep 6; say -v Karen "Give me an example."`. The first answer stays short. The follow-up
answer has 3–6 short B1 sentences in the first person, stays on the same topic, adds new facts (numbers, steps, examples)
and does not repeat the first answer.
| # | First question → short answer | Follow-up | Ideal detailed answer | Must / must not |
|---|---|---|---|---|
| 57 | What's the difference between fish and shellfish? → Fish have fins and a backbone; shellfish have a shell, like prawns, crabs, oysters and mussels. | Can you explain more? | Fish can be round, like snapper and barramundi, or flat, like flounder. Some are white and mild, others are oily, like salmon and tuna. Shellfish are crustaceans, like prawns and crabs, or molluscs, like oysters, mussels and squid. Fresh fish has bright eyes, red gills and firm flesh. I keep all seafood on ice at 0–5 °C and use it in one or two days. | Types of fish and shellfish + a freshness or storage fact with numbers. |
| 58 | What temperature is your fridge? → I keep it at 5 °C or below. | Why? | Bacteria grow fast between 5 and 60 °C, so cold food must stay at 5 °C or below. Some, like Listeria, still grow slowly in the fridge, so I also check use-by dates. I check and record the fridge temperature every day. | Gives the reason, not the number again. |
| 59 | What is a roux? → Equal weights of butter and flour cooked together to thicken sauces. | Give me an example. | For béchamel I melt 50 g butter, add 50 g flour and cook it for one or two minutes without colour. Then I slowly whisk in 500 mL warm milk and simmer it for about 20 minutes. For a Mornay sauce I add cheese at the end. | A concrete example with quantities. |
| 60 | How do you cool a big pot of soup? → I use shallow trays and an ice bath: 60 to 21 °C within two hours, then down to 5 °C within four more. | Tell me more. | First I split the soup into shallow trays and put them in an ice bath or a blast chiller, and I stir it. I check the temperature with a probe and write down the times. When it is cold, I cover it, label it with the date and put it in the fridge. If it doesn't reach 21 °C in two hours, I reheat it or throw it out. | Steps, recording and the corrective action; not only the 2h/4h numbers again. |
| 61 | Define ganache and provide common ratios for dark vs milk/white chocolate. → Ganache is chocolate melted with hot cream. For a glaze I use 1:1 dark, 2:1 milk and 3:1 white chocolate to cream. | How do you make it? | I chop the chocolate finely and heat the cream until it just simmers, about 80 °C. I pour the cream over the chocolate, wait one or two minutes, then stir from the centre until it's smooth and shiny. For a glaze I use it warm, about 32 °C. For truffles I let it set in the fridge, then roll it. | Method with temperatures. |
| 62 | What do you have on your menu? → We cook a European set menu, like lasagne and roast chicken, and Vietnamese set meals too. It changes every day. | Tell me more. | Our European set menu has a soup, a main, a side, a salad and a dessert, for example pumpkin soup with beef lasagne, or fish and chips. Our Vietnamese set meals come with rice, a braised dish, a soup, vegetables and fruit. There is always a vegetarian dish too. Both menus change every day. | European first; facts from the profile only; no day named. |
| 63 | What's the difference between fish and shellfish? → (short answer as in 57) | (within 5 s) What's your name? | My name is Minh Le. | A new, different question gets the short answer, not a detailed one. |

## Recording results
For each failed item note: question #, the app's answer, which pass rule failed. Send failures about scope or invented
facts to DATA (knowledge/guide), and failures about format, joining pieces or the "-" reply to BACK END (prompt code).
