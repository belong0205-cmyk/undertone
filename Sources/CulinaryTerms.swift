/// Domain vocabulary for an Australian commercial-cookery setting (SIT30821) where English
/// speech is mixed with French culinary terms. Sent to the speech recognizer as context so
/// these words come back spelled correctly, and reusable in the answering prompt.
enum CulinaryTerms {
    static let general: [(key: String, value: String)] = [
        ("domain", "Professional cookery"),
        ("setting", "Australian commercial kitchen training, SIT30821 Certificate III in Commercial Cookery"),
        ("languages", "English, often with French culinary terms; sometimes full French sentences"),
    ]

    static let background = """
        Chefs and cookery students talk about classical French techniques, knife cuts, stocks, \
        sauces and soups, meat, poultry and seafood, pastry and desserts, the kitchen brigade, \
        food safety under the FSANZ Food Standards Code and HACCP, and work health and safety. \
        Pastry and chocolate work covers ganache (chocolate and cream), couverture, tempering, \
        pâte à choux, pâte sablée, crème pâtissière.
        """

    /// Note for the answering model: what the transcript is and how to read recognition errors.
    static let transcriptNote = """
        The transcript comes from live speech recognition of English and French speech in a \
        professional kitchen. French culinary terms may still be mis-heard as similar-sounding \
        English words (e.g. "brune was" = brunoise, "a canal of chantilly" = a quenelle of chantilly, \
        "mirror pois" = mirepoix). Read them as the intended culinary term and use the correct \
        spelling in your answer.
        """

    static let terms: [String] = [
        // Organisation and service
        "mise en place", "brigade de cuisine", "chef de cuisine", "sous chef", "chef de partie",
        "commis", "saucier", "poissonnier", "rôtisseur", "garde manger", "pâtissier", "entremetier",
        "tournant", "plongeur", "aboyeur", "à la carte", "table d'hôte", "prix fixe", "amuse-bouche",
        "hors d'oeuvre", "entrée", "canapé", "petit four", "mignardise",
        // Knife cuts
        "brunoise", "julienne", "jardinière", "macédoine", "paysanne", "chiffonade", "mirepoix",
        "concassé", "tourné", "émincer", "ciseler", "batonnet", "allumette", "pont-neuf",
        // Methods
        "sauté", "sauter", "flambé", "flamber", "braiser", "poêler", "pocher", "blanchir", "glacer",
        "déglacer", "réduire", "monter au beurre", "nappe", "à la nappe", "gratiner", "au gratin",
        "en papillote", "sous vide", "confit", "à la meunière", "barder", "larder", "paner",
        "bain-marie", "chinois", "tamis", "mandoline", "salamander", "bratt pan",
        // Stocks, sauces and soups
        "fond blanc", "fond brun", "fumet", "court-bouillon", "consommé", "clarification", "bisque",
        "velouté", "potage", "purée", "vichyssoise", "bouillabaisse", "roux", "roux blanc", "roux blond",
        "roux brun", "beurre manié", "liaison", "panada", "béchamel", "espagnole", "sauce tomate",
        "hollandaise", "béarnaise", "mayonnaise", "demi-glace", "jus", "jus lié", "beurre blanc",
        "beurre noisette", "beurre noir", "beurre composé", "sauce mornay", "sauce soubise",
        "sauce bordelaise", "sauce chasseur", "sauce suprême", "sauce allemande", "sauce Robert",
        "vinaigrette", "rémoulade", "gastrique", "sabayon", "coulis", "aïoli", "rouille", "tapenade",
        // Aromatics and garnishes
        "bouquet garni", "sachet d'épices", "oignon piqué", "oignon brûlé", "fines herbes",
        "herbes de Provence", "matignon", "duxelles", "persillade", "lardons", "croûtons", "quenelle",
        // Dishes
        "terrine", "pâté", "rillettes", "galantine", "ballotine", "roulade", "quiche Lorraine",
        "ratatouille", "coq au vin", "boeuf bourguignon", "blanquette de veau", "cassoulet",
        "gratin dauphinois", "pommes purée", "pommes Anna", "pommes duchesse", "pommes fondantes",
        "pommes château", "salade niçoise", "steak tartare", "magret de canard", "foie gras",
        "moules marinières", "sole meunière", "escargots", "crêpe",
        // Pastry and desserts
        "pâte brisée", "pâte sucrée", "pâte sablée", "pâte feuilletée", "pâte à choux",
        "pâte à bombe", "crème pâtissière", "crème anglaise", "crème chantilly", "chantilly",
        "crème brûlée", "crème caramel", "crème fraîche", "crème d'amande", "frangipane", "chiboust",
        "ganache", "praliné", "nougatine", "tuile", "éclair", "profiterole", "croquembouche",
        "mille-feuille", "financier", "madeleine", "génoise", "dacquoise", "meringue", "macaron",
        "soufflé", "tarte Tatin", "clafoutis", "brioche", "croissant", "pain au chocolat", "bavarois",
        "mousse", "parfait", "sorbet", "entremets", "couverture", "tempering",
        // Food safety and kitchen admin (Australia)
        "FSANZ", "Food Standards Code", "HACCP", "temperature danger zone", "potentially hazardous food",
        "Food Safety Supervisor", "cross-contamination", "sanitise", "FIFO", "core temperature",
        "WHS", "SDS", "PPE", "SafeWork", "allergen", "PEAL", "GST", "yield percentage", "food cost percentage",
    ]
}
