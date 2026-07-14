### Obtaining and translating practicioner labels from REDCap

colors_user <- c(
    "Kristina Little, MD" = "#1f3c7b",
    "Thomas Cudjoe, MD, MPH" = "#f3c300",
    "Maria Yefimova, Phd, MS" = "#052049",
    "Marianthe Grammas, MD" = "#006242",
    "Debbie Freeland, MD" = "#00b6f1",
    "Julia Hiner, MD" = "#4e738a",
    "Faith Atai, MD" = "#ae6042"
)

colors_institution <- c(
    "Baylor College of Medicine - BT House Calls" = "#1f3c7b",
    "Johns Hopkins - JHOME" = "#f3c300",
    "UCSF - Care at Home" = "#052049",
    "University of Alabama - UAB House Calls" = "#006242",
    "UT Southwestern - COVE" = "#00b6f1",
    "UTH Houston - LBJ House Calls" = "#4e738a",
    "UTH Houston - UT Physicians House Calls" = "#ae6042"
)

user <- data.frame(
    site_champ = c(51, 71, 61, 11, 31, 41, 21, 99),
    site_champ_label = c(
        "Debbie Freeland, MD",
        "Faith Atai, MD",
        "Julia Hiner, MD",
        "Kristina Little, MD",
        "Maria Yefimova, Phd, MS",
        "Marianthe Grammas, MD",
        "Thomas Cudjoe, MD, MPH",
        "Not listed"
    )
)

institution <- data.frame(
    institution = c(1, 2, 3, 4, 5, 6, 7),
    institution_label = c(
        "Baylor College of Medicine - BT House Calls",
        "Johns Hopkins - JHOME",
        "UCSF - Care at Home",
        "University of Alabama - UAB House Calls",
        "UT Southwestern - COVE",
        "UTH Houston - LBJ House Calls",
        "UTH Houston - UT Physicians House Calls"
    )
)

gender <- data.frame(
    gender = c(1, 2, 98, 77),
    gender_label = c(
        "Male",
        "Female",
        "Other",
        "Unknown"
    )
)

race <- data.frame(
    race = c(1, 2, 3, 4, 5, 98, 99),
    race_label = c(
        "American Indian or Alaskan Native",
        "Asian",
        "Black or African American",
        "Native Hawaiian or Pacific Islander",
        "White",
        "Other",
        "Unknown"
    )
)

hispanic <- data.frame(
    hispanic = c(1, 0, 77),
    hispanic_label = c("Yes", "No", "Unknown")
)

rel_status <- data.frame(
    rel_status = c(1, 2, 3, 4, 5, 6, 98, 77),
    rel_status_label = c(
        "Married",
        "Living together and unmarried/Common Law relationship",
        "Separated",
        "Divorced",
        "Widowed",
        "Single/Never Married",
        "Other",
        "Unknown"
    )
)

reason <- data.frame(
    reason = c(1, 2, 3, 4, 5, 6, 98),
    reason_label = c(
        "New patient to establish care",
        "New patient for home safety evaluation",
        "New patient for transition of care",
        "Return patient for acute concern only",
        "Return patient for chronic concern only",
        "Return patient for acute and chronic concerns",
        "Not listed"
    )
)

cog_imp <- data.frame(
    cog_imp = c(0, 1, 2, 77),
    cog_imp_label = c(
        "No diagnosis",
        "Diagnosis of mild cognitive impairment",
        "Diagnosis of dementia",
        "Unknown"
    )
)

func_status <- data.frame(
    func_status = c(1, 2, 3, 4, 5, 98, 77),
    func_status_label = c(
        "Ambulates without assistance",
        "Ambulates with assistance of others",
        "Uses assistive device",
        "Wheelchair bound",
        "Bed bound",
        "Other",
        "Unknown"
    )
)

bcm_clinician <- data.frame(
    clinician_id = c(101, 102, 103, 109, 104, 105, 106, 107, 108, 198),
    clinician_name = c(
        "Allison Dobecka, NP",
        "Anita Major, MD",
        "Elizabeth Brierre, NP",
        "Julia Prentiss, NP",
        "Kim Johnson, NP",
        "Kristina Little, MD",
        "Luz Verma, MD",
        "Sarah Selleck, MD",
        "Tolu Awolaja, NP",
        "Not listed"
    ),
    clinician_randomized = c(0, 0, 1, 0, 0, 1, 0, 0, 0, 0)
)

jh_clinician <- data.frame(
    clinician_id = c(
        201,
        202,
        203,
        204,
        205,
        206,
        207,
        208,
        209,
        210,
        211,
        212,
        298
    ),
    clinician_name = c(
        "Amy Kilen, CRNP",
        "Angela Davis, CPC-1",
        "Charde Thomas, CPC-1",
        "Danielle Stewart, CHW",
        "Elizabeth (Liddy) Logan, RN",
        "Erin Hudson, CHW",
        "Mariah Robertson, MD",
        "Mary (Mae) Ellen Koontz, RN",
        "Mattan Schuchman, MD",
        "Melissa Lantz-Garnish, RN",
        "Michael Kingan, DNP",
        "Thomas Cudjoe, MD, MPH",
        "Not listed"
    ),
    clinician_randomized = c(0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0)
)

ucsf_clinician <- data.frame(
    clinician_id = c(
        301,
        302,
        303,
        304,
        305,
        317,
        306,
        307,
        308,
        309,
        318,
        310,
        311,
        312,
        319,
        320,
        313,
        314,
        315,
        316,
        398
    ),
    clinician_name = c(
        "Courtney Gordon, DNP",
        "Daniel Gordon, NP",
        "Deepa Dharmarajan, MD",
        "Eddie Lam, MD, MPH",
        "Helen Horvath, NP, MSN",
        "Jamie Rosenthal, MD",
        "Josette Rivera, MD",
        "Maria Yefimova, PhD, MS",
        "Marisa Guardado, LCSW",
        "Michael Harper, MD",
        "Monica Cheng, MD",
        "Raymond Wong, MSW",
        "Rebecca Conant, MD",
        "Robbie Zimbroff, MD",
        "Rodrigo Mojica Castillo, MD",
        "Stacy Han, MD",
        "Scott Tamblin, NP",
        "Simone Chou, RN",
        "Tamika Bailey, MD",
        "Tom Baker, RN",
        "Not listed"
    ),
    clinician_randomized = c(
        1,
        0,
        1,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        0,
        1,
        1,
        0,
        1,
        1,
        0,
        0,
        0,
        0
    )
)

uab_clinician <- data.frame(
    clinician_id = c(401, 402, 403, 404, 405, 406, 407, 408, 498),
    clinician_name = c(
        "Amber Teter, RN",
        "Jessica Nix, LICSW",
        "Katelyn Wilcoxon, RN",
        "Linda G. Jones, CRNP",
        "Lydia Casey, CRNP",
        "Marianthe Grammas, MD",
        "Meghan Peralta, CRNP",
        "Trestalyn Grimes, CM",
        "Not listed"
    ),
    clinician_randomized = c(0, 1, 1, 0, 1, 1, 0, 0, 0)
)

utsw_clinician <- data.frame(
    clinician_id = c(501, 502, 503, 504, 507, 505, 506, 508, 598),
    clinician_name = c(
        "Anupama Gangavati, MD",
        "Cara Neagoe, NP",
        "Debbie Freeland, MD",
        "Eunice Opande, NP",
        "Kayla Clark, MSW",
        "Mihoko Abegunde, NP",
        "Namirah Jamshed, MD",
        "Rincy Thomas, NP",
        "Not listed"
    ),
    clinician_randomized = c(0, 0, 1, 0, 0, 1, 1, 1, 0)
)

lbj_clinician <- data.frame(
    clinician_id = c(
        601,
        602,
        603,
        604,
        605,
        606,
        607,
        608,
        609,
        610,
        614,
        611,
        612,
        613,
        698
    ),
    clinician_name = c(
        "Grace Akwari, NP",
        "Latrell Darwin, NP",
        "Edna Garcia, NP",
        "Julia Hiner, MD",
        "Jessica Lee, MD",
        "Delphine Mepewou, NP",
        "Delma Montoya-Monge, MD",
        "Cristina Murdock, MD",
        "Theclar Omeh, NP",
        "Lillian Onyemelukwe, NP",
        "Soraira Pacheco, DO, MS",
        "Linda Pang, MD",
        "Nadia Salas, NP",
        "Ifeoma Umeh, NP",
        "Not listed"
    ),
    clinician_randomized = c(1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0)
)

utp_clinician <- data.frame(
    clinician_id = c(701, 702, 703, 704, 705, 798),
    clinician_name = c(
        "Faith Atai, MD",
        "Maureen Beck, DNP",
        "Shuyan Bi, NP",
        "Candace Johnson, NP",
        "Mona Patel, NP",
        "Not listed"
    ),
    clinician_randomized = c(1, 1, 0, 1, 0, 0)
)
