# Answer evaluation — manual check for TESTER

138 common kitchen-interview and assessment questions (including follow-ups, Australian food safety and WHS, and SA Cook questionnaire topics) with an ideal answer and what must (not) happen. The ideal answer is one good
version; other wording passes if it meets every rule below.

## Setup
1. Build and open the app. On the Hồ sơ page import `Tests/eval-profile.undertone-profile` (double-click it or use
   Import) and make "Minh Le" the active profile. It is an imaginary person; its menu has the same shape as real menus:
   Vietnamese set meals laid out over 2 weeks (Monday–Saturday) plus a European set menu by weekday, written in Vietnamese.
   The layout is only how the dishes are listed: the app treats the menu as a list of dishes to draw from, not a timetable
   (user decision 2026-11-26), so weeks, cycles and matching the day are not scored.
2. Start listening, then speak each question through the speakers from Terminal, for example:
   `say -v Karen "What do you have in your menu?"` (Karen is an Australian voice). For split questions (section E) run
   the two `say` commands with `sleep 2` between them.
3. Note whether today is a Sunday before section A (question 5 differs on a Sunday).

## Pass rules (every answer)
1. Answers the question that was asked, at the same scope: a general question gets a general answer (big picture +
   at most 2–3 examples), a specific question gets exactly that detail.
2. No invented facts: no day, date, week, time, number, price or name that was not asked for or is not in the profile /
   knowledge base. Missing fixed personal facts (name, age, address, workplace, phone number) use a placeholder in
   square brackets; soft facts (hobbies, likes) get a short general answer with no brackets.
3. As short as possible but complete: the direct answer first, with no restating of the question and no opening or
   closing line; every point the question asks for (every item, step or reason; both halves of "what and why"), nothing
   extra and no repeating. No fixed word or sentence limit. Layout: one idea per line, under 14 words. A one-idea answer
   is one or two plain lines. A list is one "- " line per item (short phrases, names only unless more is asked). Several
   parts get a short label line ending ":" each, then its lines (about 3–4), with a blank line between parts. No ** or #.
   Spoken as the user ("I", "my", "we"); never "You could say…". In this file `<br>` marks a line break in the answer and
   `<br><br>` a blank line; other wording passes if the content and layout rules hold.
4. Simple B1 English; Vietnamese dishes get simple English names.
5. Three dish branches (prompt rules 8b1a183/fbb3b10). A general food, cooking or recipe question: well-known
   traditional European dishes from the KB, never the profile menu. "What do you cook / make?" with no restaurant
   or menu named: only European dishes from the profile menu (no Vietnamese dishes, days or menu details; classic
   KB dishes if the menu has none of that kind). The restaurant, its menu or workplace named: the whole profile
   menu, European first, Vietnamese briefly after, covering each menu. The menu is a list of dishes, not a timetable:
   a menu answer passes when every dish named is on the profile menu (a European dish = one under the European heading);
   Week 1/2, cycles and matching the day are not scored, and no week or day is named unless the question names it.
6. The Vietnamese answer says the same thing in the first person ("tôi").
7. Questions that need no reply show no answer ("-" or the filler is skipped).

## A. Menu — general vs specific
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 1 | What do you have in your menu? | We cook a European set menu, like lasagne and roast chicken. We cook Vietnamese set meals too. | Must NOT name a day or week (the original bug). European dishes first; every dish named is on the profile menu. No cycle needed. |
| 2 | What kind of food do you cook? | I cook European dishes, like lasagne, fish and chips and herb roast chicken. | "What you cook" branch: only European dishes that are on the profile menu (any day). Must not name Vietnamese dishes, days, menu details or prices. If the profile menu has no European dishes, classic European dishes from the KB pass instead. |
| 3 | Tell me about your menu. | We have a European set menu with soup, a main, sides, salad and dessert. We have Vietnamese set meals too. | General only; European first; courses or dishes from the profile menu. No day, week or cycle needed. |
| 4 | What does one meal come with? | European set menu: soup, a main, a side, a salad and a dessert.<br>Vietnamese set meals: rice, a main dish, soup and vegetables. | From both menu headers: European first, then the Vietnamese set in one short sentence (cover every menu); no invented sides. |
| 5 | What's on the menu today? | Today the European menu has beef stew in red wine with mashed potato. We also have a Vietnamese set meal, like braised pork with eggs. | Dishes from the profile menu, European first (European = under the European heading). The weekday column is not scored: any menu dish passes (today's column, e.g. Tue beef stew, is the natural pick). Must not name or pick a week. On a Sunday "It is not a working day for us." is best (the profile gives the working days); menu dishes also pass. Must not invent dishes, days or hours. |
| 6 | What are you cooking on Friday? | On Friday we have fish and chips on the European menu. We also have a Vietnamese meal like caramelised prawns. | European dish first, from the European heading; every dish on the profile menu, any day (Friday's column is the natural pick, not scored). Friday may be repeated; no week named. A Vietnamese dish is optional. |
| 7 | Do you have vegetarian options? | Yes, every Vietnamese set meal has a vegetarian dish, like tofu in tomato sauce. | Yes + one real example. |
| 8 | How often does your menu change? | The dishes change through the week. We cook a European set menu, like lasagne and beef stew, and Vietnamese set meals. | The cycle is not scored: "every day", "every week" or "two weeks" from the menu layout pass, and so does a general answer; must not invent a cycle the profile does not show (monthly, seasonal). Dishes named are on the profile menu; European first. |
| 9 | What's your signature dish? | My best dishes are braised pork with eggs and sour fish soup. | Every dish in the profile's "Signature dishes" field, in simple English, and nothing else; stays Vietnamese because the profile says so. Must NOT answer with a cuisine type ("European and Vietnamese food") or with the menu. "I do not have a signature dish yet." is right only when the field is empty (no brackets, no "the profile"). |
| 10 | What do you serve on Sunday? | Sunday is not a working day for us. | Says it is not a working day (allowed because the profile gives Monday–Saturday). "No dishes are listed for Sunday" also passes. Must not invent Sunday dishes, or any days or hours not in the profile. |
| 11 | Do you serve any European food? | Yes, we have a European set menu. It has dishes like beef lasagne and fish and chips. | No day, week or cycle needed; dishes from the European heading. |
| 12 | What soup do you make? | - Pumpkin soup<br>- Mushroom soup<br>- French onion soup | "What you cook" branch: only European soups that are on the profile menu. Must not name Vietnamese soups, menu details, or a weekday unless the question does. If the profile menu has no European soup, classic European soups from the KB pass instead. |
| 129 | What risotto do you make? | - Risotto alla milanese<br>- Mushroom risotto<br>- Seafood risotto | "What you cook" branch, fallback: the eval-profile menu has no risotto, so 2–3 classic European risottos from the KB (file 07), said as my own (a dish is never a blank). Must NOT say the menu or profile lacks the dish ("The profile menu has no risotto." and "I do not have any risotto to tell you about" fail); must not talk to the user; no Vietnamese dishes, no invented menu items, no day. |

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
| 20 | Tell me about your day. | I check deliveries and fridge temperatures and prep meat and vegetables. Then I cook the braised dishes and soups for lunch. | 2–3 steps, no clock times needed. |
| 21 | What are your main responsibilities? | I cook the European soups and mains and the Vietnamese braised dishes. I also check fridge temperatures. | From the profile; European first. |
| 22 | How long have you been working as a cook? | I have about three years of kitchen experience. | 3 years. |
| 23 | Do you have any certificates? | Yes, I have a Food Safety Supervisor certificate and a First Aid certificate. | Both, no invented ones. With an empty Certificates field: one short first-person sentence saying none yet ("I do not have any certificates yet."), no brackets, never mention "the profile". |
| 24 | What languages do you speak? | I speak Vietnamese and some English. | — |

## C. Missing personal facts → placeholder or short general answer
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 25 | What are your hobbies? | In my free time I like cooking and walking. | Hobbies are empty: a short general first-person answer. No brackets, template text, names, places or numbers. |
| 26 | What's your phone number? | My phone number is [your phone number]. | Must not invent digits. |
| 27 | Where do you live? | I live in [your suburb]. | Must not use the workplace. |

## D. Cookery knowledge (Certificate III)
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 28 | What temperature should the fridge be? | We keep the fridge at 5 °C or below. | Australian 5 °C, not 40 °F. |
| 29 | What is the temperature danger zone? | It's between 5 and 60 °C. Cold food stays at 5 or below, hot food at 60 or above. | 5–60 °C. |
| 30 | How do you cool down a big pot of soup? | - Shallow trays and an ice bath<br>- From 60 to 21 °C within two hours<br>- Then down to 5 °C within four more hours | 2h/4h rule. |
| 31 | What core temperature do you cook chicken to? | I cook chicken to at least 75 °C in the thickest part. | 75 °C. |
| 32 | What's the difference between cleaning and sanitising? | Cleaning removes dirt, food and grease with detergent and water. Sanitising kills bacteria, usually with a sanitiser or very hot water. We always clean first and sanitise after, because sanitiser does not work well on dirty surfaces. | Fixed answer (Knowledge/fixed-answers.md), shown word for word without calling the AI; not the comparison shape, nothing added or cut. |
| 33 | What is FIFO? | FIFO means first in, first out. We use older stock first and put new stock at the back. | — |
| 34 | What are the five mother sauces? | - Béchamel<br>- Velouté<br>- Espagnole<br>- Tomato sauce<br>- Hollandaise | All five. |
| 35 | What is a brunoise? | Brunoise is a very small dice, about 2 mm, cut from julienne. | ~2 mm. |
| 36 | How do you stop cross-contamination? | - Colour-coded boards<br>- Raw meat below cooked food<br>- Wash hands and sanitise between tasks | — |
| 37 | A customer has a nut allergy. What do you do? | - Check every ingredient<br>- Clean the bench and tools, use separate equipment<br>- Tell the chef and the server | No "it's probably fine". |
| 38 | What is mise en place? | It means having everything ready before service. Ingredients are prepped, tools are ready and my station is set up. | — |
| 39 | How do you work out the food cost percentage? | I divide the food cost by the selling price without GST. Then I multiply by 100. | Ex-GST. |
| 40 | What do you use on a deep-fryer fire? | A wet chemical extinguisher or a fire blanket, never water. | Class F, no water. |

## E. Questions in pieces
| # | Pieces (about 2 s apart) | Ideal answer | Must / must not |
|---|---|---|---|
| 41 | "What do you usually…" + "cook on Fridays?" | On Fridays we cook fish and chips on the European menu. We also cook Vietnamese dishes like caramelised prawns. | Answers the joined question, once; European dish first, from the European heading; every dish on the profile menu, any day (Friday's column not scored); no week named. A Vietnamese dish is optional. |
| 42 | "How many people…" + "work in your kitchen?" | There are eight people in our kitchen. | Not an answer to the first piece alone. |
| 43 | "Do you usually cook?" + "At your restaurant?" | Yes, I cook every day at work. I cook European soups and mains, and Vietnamese braised dishes. | One answer for both pieces; European first. |

## F. No answer expected
| # | Utterance | Expected |
|---|---|---|
| 44 | Okay. | No answer (filler). |
| 45 | Yes, chef. | No answer (filler). |
| 46 | Let's get started with the interview. | "-" (a statement, no question). |

## G. Define / Explain / List (assessor style)
Answers give the definition and every item or number asked for, not a full lesson (rule 3).
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 47 | Define ganache and provide common ratios for dark vs milk/white chocolate. | Ganache: chocolate melted with hot cream.<br><br>Ratios, chocolate to cream:<br>- Dark 1:1, for a glaze<br>- Milk 2:1<br>- White 3:1 | Definition + ratios for all three; milk and white need more chocolate than dark. Accept truffle ratios (2:1 dark, 2.5–3:1 milk, 3–4:1 white) if the use is named. |
| 48 | What is an emulsion? Give an example. | An emulsion is oil and water mixed into tiny drops. Examples are mayonnaise and a vinaigrette. | Definition + example. |
| 49 | Explain the three types of roux. | All equal flour and butter:<br>- White: no colour<br>- Blond: light golden<br>- Brown: nut brown | Equal weights; white / blond / brown. |
| 50 | List the five mother sauces. | - Béchamel<br>- Velouté<br>- Espagnole<br>- Tomato sauce<br>- Hollandaise | Names only, all five. |
| 51 | How do you temper dark chocolate? | - Melt to 45–50 °C<br>- Cool to 27–28 °C<br>- Warm to 31–32 °C | Three temperatures. |
| 52 | What is a liaison? | A liaison is egg yolks and cream. I add it at the end to thicken a sauce or soup. I never boil it after. | No boiling. |
| 53 | What's the difference between braising and stewing? | Main difference: Braising cooks large pieces in little liquid; stewing covers small pieces.<br><br>Braising:<br>- Best for: large tough cuts like beef cheeks, lamb shanks, osso buco<br>- Limit: long, gentle oven time, about 150 °C; boiling makes it tough<br><br>Stewing:<br>- Best for: small even pieces of cheaper cuts, served in their liquid<br>- Limit: the liquid is served as is, not reduced to a sauce<br><br>Trade-off: Both make tough cuts tender; braising keeps the piece whole. | Comparison shape (section L); must match KB 04 (Stewing, Braising); no invented times. |
| 54 | Name the three types of meringue. | - French<br>- Swiss<br>- Italian | Names only. |
| 55 | What is the difference between crème anglaise and crème pâtissière? | Main difference: Anglaise is a thin pouring custard; pâtissière is thickened with flour.<br><br>Crème anglaise:<br>- Best for: pouring sauce, ice cream base and bavarois<br>- Limit: cook only to 82–84 °C; boiling curdles it<br><br>Crème pâtissière:<br>- Best for: pastry fillings and hot soufflé bases<br>- Limit: must boil 1–2 minutes to cook the starch; high-risk, chill fast<br><br>Trade-off: Pâtissière holds its shape; anglaise stays pourable and smooth. | Comparison shape (section L); anglaise never boiled, pâtissière boiled (KB 12). |
| 56 | What does HACCP stand for? | Hazard Analysis and Critical Control Points. It's a system to control food safety hazards at key steps. | Full name correct. |

## H. Follow-up — more detail (within about 10 s)
Ask the first question, wait for its short answer, then ask the follow-up within 10 s, e.g.
`say -v Karen "What is a roux?"; sleep 6; say -v Karen "Give me an example."`. The first answer stays short. The follow-up
answer is a few short B1 lines in the first person, stays on the same topic, adds new facts (numbers, steps, examples)
and does not repeat the first answer.
| # | First question → short answer | Follow-up | Ideal detailed answer | Must / must not |
|---|---|---|---|---|
| 57 | What's the difference between fish and shellfish? → Main difference: Fish have fins and a backbone; shellfish have a shell.<br><br>Fish:<br>- Best for: grilling, pan-frying, poaching and baking<br>- Limit: delicate flesh breaks up and overcooks fast<br><br>Shellfish:<br>- Best for: steaming, grilling and very fast frying<br>- Limit: a few minutes too long makes it rubbery or tough<br><br>Trade-off: Both cook fast and spoil fast, so buy fresh and keep cold. | Can you explain more? | Fish:<br>- Round, like snapper and barramundi, or flat, like flounder<br>- White and mild, or oily, like salmon and tuna<br><br>Shellfish:<br>- Crustaceans: prawns, crabs<br>- Molluscs: oysters, mussels, squid<br><br>Freshness and storage:<br>- Bright eyes, red gills, firm flesh<br>- On ice at 0–5 °C, used in one or two days | First answer in the comparison shape (section L); the follow-up adds types and a freshness or storage fact with numbers, no repeat; examples not in the first person. |
| 58 | What temperature is your fridge? → I keep it at 5 °C or below. | Why? | Bacteria grow fast between 5 and 60 °C. So cold food must stay at 5 °C or below. Some, like Listeria, still grow slowly in the fridge. So I also check use-by dates. I check and record the fridge temperature every day. | Gives the reason, not the number again. |
| 59 | What is a roux? → Equal weights of butter and flour cooked together to thicken sauces. | Give me an example. | White roux for béchamel:<br>- 50 g butter and 50 g flour<br>- Cook one or two minutes, no colour<br>- Whisk in 500 mL warm milk slowly: 100 g roux per 500 mL, a coating sauce<br>- Simmer about 20 minutes to cook out the flour taste<br>- Add cheese at the end for Mornay | A concrete example with quantities and times from the KB. |
| 60 | How do you cool a big pot of soup? → I use shallow trays and an ice bath. The soup goes from 60 to 21 °C within two hours. Then it goes down to 5 °C within four more hours. | Tell me more. | - Split into shallow trays, about 5 cm deep<br>- Ice bath or blast chiller, and stir<br>- After two hours, probe the centre: 21 °C or below<br>- After four more hours: 5 °C or below<br>- Write down each time and temperature<br>- Cover, date label, fridge<br>- Misses the times: throw it out, reheating does not make it safe | Steps; probe after 2 h (21 °C or below) and 4 more h (5 °C or below), record; cover, date label, fridge; corrective action (throw out, not reheat). "About 5 cm deep" is correct (SFA p.41). Must not invent other check times, like every 30 minutes. |
| 61 | Define ganache and provide common ratios for dark vs milk/white chocolate. → Ganache is chocolate melted with hot cream. For a glaze I use 1:1 dark chocolate to cream. Milk chocolate is 2:1 and white chocolate is 3:1. | How do you make it? | - Chop the chocolate finely<br>- Heat the cream until it just simmers, about 80 °C<br>- Pour over the chocolate, wait one or two minutes<br>- Stir from the centre until smooth and shiny<br>- Glaze: use it warm, about 32 °C<br>- Truffles: set it in the fridge, then roll | Method with temperatures. |
| 62 | What do you have on your menu? → We cook a European set menu, like lasagne and roast chicken. We cook Vietnamese set meals too. | Tell me more. | European set menu:<br>- Soup, main, side, salad and dessert<br>- Example: mushroom soup with beef stew in red wine<br><br>Vietnamese set meals:<br>- White rice and a main, like braised pork with eggs or caramelised prawns<br>- A stir-fry, soup, vegetables and dessert<br>- Always a vegetarian dish, like tofu in tomato sauce | Must give each set's courses from the menu headings (European: soup, main, side, salad, dessert) and name at least one specific Vietnamese dish besides rice, in English. Every dish named must be on the profile menu (any week or day) and said in English, never in Vietnamese. European first; no day, week or cycle named; adds new facts, does not repeat the first answer's dishes. |
| 63 | What's the difference between fish and shellfish? → (comparison answer as in 57) | (within 5 s) What's your name? | My name is Minh Le. | A new, different question gets the short answer, not a detailed one. |

## I. Australian food safety and WHS (answers must match the source)
Short B1 answers in the first person ("I"), complete on every point asked. A Code requirement must not be swapped for a guidance figure, or the other way round.
| # | Question | Ideal answer | Must / must not | Source |
|---|---|---|---|---|
| 64 | What temperature must potentially hazardous food be when you receive it? | - Cold food: 5 °C or below<br>- Hot food: 60 °C or above<br>- Frozen food: still frozen | Both limits + frozen. | FSANZ 3.2.2 cl 5(3)–(4) |
| 65 | How fast must you cool cooked food? | From 60 to 21 °C within two hours. Then down to 5 °C within a further four hours. | Both stages. | 3.2.2 cl 7(3) |
| 66 | What temperature do you reheat food to for hot holding? | I reheat it quickly to at least 60 °C. I aim for 75 °C in the centre. I never reheat in a bain-marie. | 60 °C is the Code limit; 75 °C only as a recommendation. | 3.2.2 cl 7(4); FSANZ guidance |
| 67 | What does sanitise mean? | Sanitising means using heat or chemicals on a clean surface. It reduces germs to a safe level. | Must NOT say it kills all germs. | 3.2.2 cl 20(2) |
| 68 | How can you sanitise utensils? | - Hot water at 77 °C for 30 seconds<br>- A chemical sanitiser, as the label says<br>- A dishwasher sanitising cycle | Heat, chemical, or both. | FSANZ cleaning and sanitising; Safe Food Australia App. 6 |
| 69 | What must you do if you have diarrhoea? | I tell my supervisor and I don't handle food. I stay away from food until 48 hours after the symptoms stop. | Report + no food handling; 48 h as health advice. | 3.2.2 cl 14; state health guidance |
| 70 | When must you wash your hands? | - Before I handle food<br>- After the toilet<br>- After raw food, before ready-to-eat food<br>- After coughing, sneezing, eating or touching my hair | At least 3 of these times. | 3.2.2 cl 15(2)–(3) |
| 71 | What does a food safety supervisor need? | - A food safety supervisor certificate from the last five years<br>- Authority to direct staff<br>- Reasonably available | 5 years. | 3.2.2A cl 2, 11 |
| 72 | How long do you keep food safety records? | We're a category one business, so we keep them for at least three months. | 3 months. | 3.2.2A cl 12(2) |
| 73 | Which allergens must be declared in Australia? | - Milk, egg<br>- Peanut, tree nuts, sesame<br>- Soy, wheat, gluten cereals, lupin<br>- Fish, crustacea, molluscs<br>- Sulphites | Lupin and sesame included; no "mustard" or "celery" (EU list). | FSANZ PEAL, Std 1.2.3 and Schedule 9 |
| 74 | What is the hierarchy of control? | - Eliminate the hazard<br>- Substitute it<br>- Isolate it<br>- Engineering controls<br>- Administrative controls<br>- PPE last | Correct order. | Model WHS Regulations r 36 |
| 75 | What is an SDS? | A Safety Data Sheet. It tells me a chemical's hazards, safe use, storage, PPE and first aid. | — | Model WHS Regulations; Safe Work Australia |
| 76 | How do you lift a heavy box of stock safely? | - Check the weight first<br>- Heavy: use a trolley or get help<br>- Bend my knees, keep the box close to my body | Assess first, aids or help. | Safe Work Australia Code of Practice: Hazardous manual tasks |

## J. SA Cook questionnaire topics (answers must match the KB)
Short B1 answers in the first person ("I"), complete on every point asked. The KB fact column names the knowledge file and the note the answer must agree with.
| # | Question | Ideal answer | Must / must not | KB fact |
|---|---|---|---|---|
| 77 | I had gastro but I feel better this morning. What do you do? | I phone my supervisor before my shift and stay home. I come back only 48 hours after the symptoms stop. | Phone, not text; 48 h. Must NOT say feeling better is enough. | 01 Sick procedure (SITXFSA005) |
| 78 | How do you check that a probe thermometer is accurate? | - Probe in crushed ice with a little water<br>- Wait about 3 minutes<br>- It must read 0 °C, within 1 °C | Ice point 0 °C, ±1 °C; about 3 minutes (FSANZ). | 01 Thermometer ice-point check; 3.2.2 cl 22 |
| 79 | Your thermometer reads 6 °C in ice water. What do you do? | It's 6 degrees out, so I stop using it.<br>- Tag it and use a backup<br>- Tell my supervisor<br>- Recheck the food it measured | Outside ±1 °C → stop using it. Must NOT call 6 °C fine because it is near 5 °C. | 01 Ice-point check, 6 °C case |
| 80 | How do you store food in the cool room, from top to bottom? | Top to bottom:<br>- Cooked and ready-to-eat food<br>- Vegetables<br>- Raw seafood<br>- Raw meat and mince<br>- Raw chicken at the bottom | Ready-to-eat on top, raw poultry at the bottom; raw never above ready-to-eat. | 01 Cool room order |
| 81 | Two cooks are arguing during service. What do you do? | I calmly ask them to stop and step away from the line. I call the supervisor, and we sort it out after service. | Safety, supervisor, private talk after service; must not take sides. | 14 Two cooks arguing (SITHCCC043) |
| 82 | What do you write in a handover note? | - Prep done and still to do<br>- Food cooling, with its start time<br>- Low stock<br>- Equipment faults and allergen notes | At least 3 items from the KB list. | 14 Handover notes |
| 83 | What do you go through in a shift briefing? | - Covers and bookings<br>- Specials, menu changes and 86'd items<br>- Allergies and dietary requests<br>- Our sections | Allergies + at least 2 more items. | 14 Shift briefing |
| 84 | What's the difference between cross-contamination and cross-contact? | Main difference: Cross-contamination moves bacteria; cross-contact moves an allergen.<br><br>Cross-contamination:<br>- Example: raw chicken juice dripping onto salad<br>- Control: separate boards, raw stored below ready-to-eat, cook to 75 °C<br><br>Cross-contact:<br>- Example: the same knife for satay, then salad<br>- Control: clean and sanitise first, separate purple equipment, allergen-free orders first<br><br>Trade-off: Cooking kills bacteria but does not remove allergens. | Comparison shape (section L); for a pair that is not a choice, "Best for / Limit" may read Example / Control. Allergen = cross-contact; cooking does not remove allergens. Examples not in the first person (no "I use the same knife…"). | 13 Cross-contamination vs cross-contact |
| 85 | A customer has an allergic reaction to a dish. What do you do? | - Call 000 and give first aid<br>- Tell the manager<br>- Keep the dish and packaging<br>- Write an incident report | 000 and first aid first; keep the dish. | 13 Allergen incident |
| 86 | A chicken pasta costs $4.50 a portion and the target food cost is 30%. What's the menu price? | $4.50 divided by 0.30 is $15 without GST. So the menu price is $16.50 with GST. | $15.00 ex-GST, $16.50 with GST; must NOT use $4.50 × 1.3. | 16 Costing a chicken pasta dish |
| 87 | The price of seafood goes up a lot. What do you do? | - Re-cost the recipe first<br>- Raise the price a little, or trim the portion<br>- Use a cheaper fish, or talk to suppliers | Re-cost first + at least 2 options. | 16 Supplier price rise |
| 88 | How do you handle a customer complaint? | - Listen and apologise<br>- Solve the problem<br>- Thank the customer<br>- If I can't fix it, get my supervisor | LAST order (Listen, Apologise, Solve, Thank); escalate. | 20 Complaints (SITXCCS014) |
| 89 | How do you answer the phone at work? | - Answer within three rings<br>- Greeting, our business name and my name<br>- Speak clearly | Three rings; greeting, business name, own name. | 20 Phone (SITXCCS014) |
| 90 | Explain the 2-hour/4-hour rule with an example. | Rule:<br>- Under 2 hours out of the fridge: use it, or chill it again<br>- 2 to 4 hours: use it now<br>- Over 4 hours: bin it<br><br>Example:<br>Sandwiches out at 10: chill by 12, use by 2, then bin. | All three bands; times add up; a worked example. | 00 2-hour/4-hour rule (Safe Food Australia App. 2) |
| 91 | How fast must you reheat cooked food to hold it hot? | I reheat it fast to 60°C or above, within 2 hours. I aim for 75°C in the centre. I reheat only once. | ≥60 °C within 2 h (FSANZ); reheat once; must NOT say reheat in the bain-marie. | 01 Reheating, 3.2.2 cl 7(4) |
| 92 | How often do you calibrate your thermometer? | The Code sets no fixed time. I follow our food safety program. We check it weekly, and after any drop or odd reading. | Says no fixed legal time; workplace schedule; after a drop or odd reading. | 01 Thermometer check frequency (NSW Food Authority ≥ 6-monthly) |
| 93 | Name six mise en place tasks before dinner service. | - Read the prep list<br>- Portion meat and fish<br>- Make stocks and sauces<br>- Cut vegetables<br>- Set up pans and boards<br>- Label my station | Six tasks from the KB list. | 14 Mise en place |
| 94 | Give three examples of cross-contamination. | - Raw chicken juice drips onto a salad<br>- One board for raw meat, then salad<br>- Unwashed hands touch ready-to-eat food | Three examples; raw → ready-to-eat. | 01 Cross-contamination examples |
| 95 | How do you clean a deep fryer? | - Switch it off, let the oil cool fully<br>- Drain the oil<br>- Boil it out with fryer cleaner<br>- Rinse and dry before refilling | Cool first; dry before refilling (water + hot oil); PPE acceptable extra. | 15 Deep fryer (SITHKOP009) |
| 96 | What is gelatinisation? | Starch heated in liquid, at about 60 to 80°C, takes in water and swells. This thickens the liquid. It happens in pasta, rice and roux sauces. | Starch + heat + liquid; swell/thicken; ~60–80 °C; a farinaceous example. | 07 Gelatinisation (SITHCCC030) |
| 97 | What is mirepoix and what's the ratio? | Mirepoix: rough-cut onion, carrot and celery, for flavouring stock.<br>Ratio: half onion, a quarter carrot, a quarter celery. | Onion, carrot, celery; 2:1:1 (50/25/25). | 06 Mirepoix (SITHCCC029) |
| 98 | How is demi-glace made? | - Equal parts espagnole and brown stock<br>- Reduce by half, skim and strain<br>Glossy, deep brown, and it coats a spoon. | Espagnole + brown stock, reduced by half; at least 2 quality signs. | 06 Demi-glace |
| 99 | What's a complete protein? | It has all nine essential amino acids, like soy, quinoa, eggs and dairy. Grains and legumes are incomplete, so I combine them: dhal with rice. | 9 essential amino acids; one complete example; a combination. | 08 Complete vs incomplete proteins (SITHCCC031) |
| 100 | What can replace gelatine in a vegan dessert? | I use agar-agar. It comes from seaweed, sets firmer and must be boiled. Pectin works for fruit jellies. | Agar-agar named; must NOT suggest gelatine-based or animal products. | 08 Gelatine replacers |
| 101 | Which cooking methods suit delicate fish? | For whiting or John Dory:<br>- Poach, steam, or bake in paper<br>- Or pan-fry gently, with a light flour coating<br>- Turn it once | Gentle methods (≥2 of poach/steam/en papillote/gentle pan-fry); must NOT say hard grilling or boiling. | 10 Delicate fish (SITHCCC037) |
| 102 | A customer asks if a dish has shellfish. What are your obligations? | - Fish, crustacea and molluscs are three separate allergens<br>- Check the recipe with the chef, never guess<br>- Tell the customer and mark the docket | Three separate allergens; check, never guess; docket. | 10 Seafood allergens, Standard 1.2.3 |
| 103 | Name two ways to emulsify a salad dressing. | - Whisk oil and vinegar with mustard: a temporary emulsion<br>- Whisk oil slowly into egg yolk: permanent, like mayonnaise | Temporary (whisk/shake) and permanent (yolk, slow oil). | 05 Emulsification (SITHCCC028) |
| 104 | How do you truss a chicken and why? | How:<br>- Tuck the wing tips under<br>- Cross the legs, tie with string around the body<br><br>Why:<br>The bird stays compact and cooks evenly. | Method with string; even cooking or shape. | 09 Trussing (SITHCCC035) |
| 105 | How do you check poultry is cooked? | - Probe the thickest part of the thigh, off the bone: 75 °C<br>- Juices run clear<br>- Leg moves freely, flesh is firm | 75°C thigh, clear juices, a texture cue. | 09 Doneness checks (SITHCCC035) |
| 106 | How do you reheat a chicken dish safely? | - Once only, fast, to 75 °C in the centre<br>- Serve it, or hold it at 60 °C or above<br>- Never in a bain-marie | Once only; rapid; 75°C or ≥60°C; no bain-marie. | 09 Reheating poultry dishes (SITHCCC035) |
| 107 | Define carry-over cooking. | Off the heat, the core keeps rising about 3 to 5 degrees. So I take it off early and rest it. | Core keeps rising; pull early. | 09 Carry-over cooking (SITHCCC036) |
| 108 | A steak is tough and dry. Give three causes. | - Overcooked<br>- Not rested, or cut with the grain<br>- A tough cut cooked too fast | Three distinct causes. | 09 Tough, dry steak (SITHCCC036) |
| 109 | What does the Maillard reaction do when you sear meat? | Above about 140°C the dry surface browns. That gives a crust, colour and deep flavour. It does not seal in the juices. | Browning and flavour; must not claim it seals in juices. | 09 Searing and the Maillard reaction (SITHCCC036) |
| 110 | Give five causes of choux failure and a fix for each. | - Collapsed: underbaked, so bake until dry<br>- Heavy, not hollow: too much egg, so add egg slowly<br>- Soggy: filled too early, so fill near service<br>- Flat: mix too soft, so keep a piping consistency<br>- Cracked: piped unevenly, so pipe evenly | Five causes, each with a fix (KB: collapsed, heavy, soggy, flat, cracked). | 11 Choux failures and fixes (SITHCCC041) |
| 111 | What is yeast fermentation and how does it affect bread? | Fermentation: yeast feeds on sugars and makes carbon dioxide and alcohol.<br><br>Effect on bread:<br>- The gas lifts the dough and opens the crumb<br>- The alcohol adds flavour | CO₂ lifts dough; flavour. | 11 Fermentation (SITHCCC041) |
| 112 | What are the quality indicators of a finished dessert? | - Texture true to type<br>- Balanced flavour<br>- Right temperature and portion<br>- Neat plating, fresh garnish | Texture, flavour balance, presentation. | 12 Quality indicators (SITHPAT016) |
| 113 | A customer says "I'm allergic to gluten" but orders soy sauce. What do you do? | - Explain that regular soy sauce has wheat<br>- Offer gluten-free tamari, or leave it out<br>- Mark the docket and tell the chef | Explain wheat; offer tamari or omit; docket and chef. | 13 Soy sauce scenario (SITHCCC042) |
| 114 | Give five sources each of protein, carbohydrates and fats. | Protein: meat, fish, eggs, dairy, legumes.<br>Carbohydrates: bread, rice, pasta, potatoes, oats.<br>Fats: olive oil, butter, avocado, nuts, oily fish. | Five correct items in each group. | 13 Five sources (SITHCCC042) |
| 115 | Why is cleaning and sanitising important in a commercial kitchen? | - Removes food and grease where bacteria grow, so no food poisoning<br>- Stops cross-contamination<br>- Protects allergy customers<br>- Meets the Food Standards Code | Must mention bacteria/food poisoning and the law; must not say "it looks nice" only | 15: why cleaning and sanitising matter — Std 3.2.2 cl 19–20 |
| 116 | What PPE should you wear when cleaning the kitchen? | - Rubber gloves<br>- Waterproof apron<br>- Enclosed non-slip shoes<br>- Goggles when splashing or decanting, a mask if the SDS says so | Must list gloves, eye protection, apron, non-slip shoes | 15: PPE for cleaning |
| 117 | How do you prevent cross-contamination during kitchen cleaning? | - Cover or move food first<br>- Clean from cleanest to dirtiest, high to low<br>- Separate colour-coded cloths: food surfaces, floors, toilets<br>- Sanitise food surfaces at the end | Must mention separate cloths and order of cleaning | 15: preventing cross-contamination while cleaning |
| 118 | What do you do if you spill cleaning chemicals on the kitchen floor? | - Warn others, put up a sign<br>- PPE on, check the SDS<br>- Contain it with the spill kit, then wipe and rinse the floor<br>- Ventilate, bin the waste safely, report it | Must include warn/sign, PPE, SDS, spill kit, report | 15: chemical spill on the floor |
| 119 | How should knives be cleaned safely? | - Wash one at a time, blade away from me<br>- Never leave a knife in a sink of water<br>- Wash, rinse, sanitise, dry at once<br>- Store it in a rack | Must say never leave in sink water and one at a time | 15: knives and sharp tools |
| 120 | What are the risks of using the wrong chemical on a food preparation surface? | - It can poison or taint the food<br>- It can corrode the surface<br>- Fumes hurt staff<br>- It may not kill bacteria, so food is unsafe | Must mention chemical contamination of food and ineffective sanitising | 15: wrong chemical on a food surface |
| 121 | A thermometer used for cooked chicken was not sanitised before checking a salad. What problem could occur? | Bacteria move from the chicken to the salad: cross-contamination. The salad is eaten raw, so customers can get food poisoning. | Must say cross-contamination and food poisoning. The fix (sanitise between foods) is not asked, so not required. | 15: unsanitised thermometer |
| 122 | What should you do if you notice signs of pests in the kitchen? | - Tell the supervisor at once<br>- Isolate and throw out contaminated food<br>- Clean and sanitise the area<br>- Record it and call the licensed pest controller | Must include report, discard contaminated food, licensed pest controller | 15: pest control — signs and action |
| 123 | During service a staff member stores dirty equipment beside clean dishes. How would you manage it? | - Calmly move the dirty items to the dirty side<br>- Re-wash and sanitise any clean items they touched<br>- Remind them of the dirty-to-clean flow<br>- Tell the supervisor | Must include re-sanitising affected clean items and calm communication | 15: dirty equipment beside clean dishes |
| 124 | What is the difference between an à la carte menu and a buffet menu? | Main difference: À la carte is cooked to order; a buffet is self-service.<br><br>À la carte:<br>- Best for: more choice, each dish priced and costed exactly<br>- Limit: more labour and a higher waste risk<br><br>Buffet:<br>- Best for: one fixed price, bulk cooking, less labour per cover<br>- Limit: guests serve themselves, so portion control is lost<br><br>Trade-off: À la carte controls portions; a buffet saves labour but risks waste. | Comparison shape (section L); both definitions; cooked to order vs self-service. | 16: à la carte vs buffet |
| 125 | How do seasonal ingredients influence recipe planning and costing? | In-season produce is cheaper and better quality, so I plan menus around the seasons. Out-of-season items are dear, so I use "market price". | Must link season to price and quality | 16: seasonal ingredients |
| 126 | What is food cost percentage and why is it important? | Food cost %: portion cost divided by selling price without GST, times 100.<br><br>Why it matters:<br>- Shows how much of each dollar goes on food<br>- Helps me set prices and spot waste | Must give the formula and a reason; ex-GST | 16: food cost % line |
| 127 | How do cultural and ethnic influences affect recipe development? | The customers' backgrounds shape ingredients, flavours and methods, like halal or kosher. I use authentic ingredients, respect religious food rules and describe dishes honestly. | Must mention religious/cultural food rules and authenticity | 16: cultural and ethnic influences |
| 128 | Why is feedback important when planning and improving recipes? | Feedback from customers, floor staff, sales and plate waste shows what to change. I test the change and update the standard recipe. | Must mention a source of feedback and updating the standard recipe | 16: feedback |

## K. Interview questions (facts from the eval profile only; blanks for what it lacks)
Minh Le's profile gives: commis chef at Green Bowl Catering (set lunches for offices), 3 years, kitchen hand at an unnamed
Vietnamese restaurant in 2023–2024, Certificate III in Commercial Cookery, Food Safety Supervisor and First Aid certificates,
goal chef de partie in two years, no notes about the job applied for. Anything else (employer names, numbers, stories) must be
a blank in square brackets. When the question is unclear, one thinking-aloud opening line is allowed (exception to rule 3).
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 130 | Tell me about yourself. | I am a commis chef at Green Bowl Catering. We cook set lunches for offices.<br>I have three years in kitchens and a Certificate III in Commercial Cookery.<br>I am good at braising, stir-frying and working fast in lunch service.<br>My goal is to be a chef de partie in two years. | 3–4 lines; role, workplace, years, qualification and goal from the eval profile only. Must not invent other employers, awards, numbers or a city; no life story. |
| 131 | Tell me about a time you handled a conflict in the kitchen. | Situation: [when], at [where], a disagreement with [who] about [what]<br>Task: I had to keep service running and sort it out calmly<br>Action: I listened first, stayed calm, agreed a plan and told the chef<br>Result: [what happened]; we finished service and agreed how to work next time | Four lines labelled Situation, Task, Action, Result in that order. The eval profile has no such story, so who, where, when and the outcome are blanks in square brackets; must not invent a colleague, venue, date or number. B1. |
| 132 | What is the difference between braising and stewing? | Main difference: Braising cooks large pieces in little liquid; stewing covers small pieces.<br><br>Braising:<br>- Best for: large tough cuts like beef cheeks, lamb shanks, osso buco<br>- Limit: long, gentle oven time, about 150 °C; boiling makes it tough<br><br>Stewing:<br>- Best for: small even pieces of cheaper cuts, served in their liquid<br>- Limit: the liquid is served as is, not reduced to a sauce<br><br>Trade-off: Both make tough cuts tender; braising keeps the piece whole. | Comparison shape (section L), facts as facts, no "I usually" and no story; must match KB 04 (Stewing, Braising); no invented times or temperatures. |
| 133 | Why should we hire you? | - Three years in kitchens, cooking both a European set menu and Vietnamese dishes<br>- Certificate III and a Food Safety Supervisor certificate<br>- Fast and clean in lunch service<br>- I want to grow into a chef de partie with you | 3–4 lines, each a fact or skill from the eval profile (years, menus, certificates, speed, goal). Must not invent awards, former employer names, covers per day or percentages; no "I am the best". |
| 134 | How do you work? | - I set up my section first: prep list, mise en place, fridge checks<br>- I keep it clean as I go and label everything<br>- I talk to the chef and call out when I need help<br>- In lunch service I stay calm and work fast | Vague question: answers directly about method, hygiene, teamwork and pressure; must not ask "What do you mean?". 3–4 lines; routine details only from the eval profile. |
| 135 | Which restaurants did you work at before Green Bowl? | Before Green Bowl I worked at [restaurant name], a Vietnamese restaurant.<br>I was a kitchen hand there in 2023–2024. | Role and years from the eval profile; the missing name is a hinted blank inside the spoken sentence. Must not invent a name, suburb or extra jobs; must not say "I do not have any restaurants to tell you about"; must not talk to the user ("You could say…") or explain the blank. |
| 136 | What would you do if it goes wrong? | Let me think for a second.<br>Do you mean a dish or the whole service?<br>If a dish: I tell the chef at once and remake it.<br>If the service: I call for help, keep my section calm and keep food safe. | Unclear question: one clarifying question, then an assumption with a short answer under it. The thinking-aloud first line is optional (rule 3 exception). Must not answer one guessed meaning without saying so; no invented facts. |
| 137 | Do you have any questions for us? | - How big is the kitchen team on a normal shift?<br>- What does a typical week of shifts look like?<br>- How do you train new cooks on your menu? | 2–3 short questions about the role, team or shifts. Must not answer "No"; must not state facts about the employer that the eval profile lacks (venues, awards). |

## L. Comparison shape (normal kitchen question, not interview)
Any comparison ("difference between", "vs", "X or Y", "which is better") uses this shape, never paragraphs, with facts
as facts ("Braising uses…"), not "I usually…"; a wrong-action example is never in the first person ("the same knife
for satay, then salad", not "I use the same knife…"): `Main difference:` one sentence; one block per option with its
name as the label line and two lines `- Best for:` and `- Limit:` (Example / Control when the pair is not a choice);
`Trade-off:` one sentence. Blank line between parts, every line under 14 words. Rows 53, 55, 57, 84, 124, 132 and 138
use it; row 32 is a fixed answer. Two-terms shape (Means / Example, no Trade-off) planned for 0.5.22, not active.
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 138 | Which is better for beef chuck, grilling or braising? | Main difference: Grilling is fast dry heat; braising is slow cooking in liquid.<br><br>Grilling:<br>- Best for: tender quick cuts like steaks, cutlets and chicken breast<br>- Limit: a tough cut stays chewy; collagen has no time to soften<br><br>Braising:<br>- Best for: hard-working cuts like chuck, shin and cheek<br>- Limit: takes hours in a gentle oven, about 150 °C<br><br>Trade-off: Braising wins for chuck; grilling only suits tender cuts. | Picks braising in the Trade-off line; must match KB 04 (Grilling, Braising) and 09 (tender vs tough cuts); no invented times; no "I usually". |

## Recording results
For each failed item note: question #, the app's answer, which pass rule failed. Send failures about scope or invented
facts to DATA (knowledge/guide), and failures about format, joining pieces or the "-" reply to BACK END (prompt code).
