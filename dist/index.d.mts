type VerificationStatus = "unverified" | "verified" | "mattia_reviewed";
type Verdict = "steal" | "worthy" | "fair" | "meh" | "not_worthy";
type TrustLevel = "new" | "contributor" | "trusted" | "banned";
type UserRole = "user" | "moderator" | "admin";
type MarketSegment = "ultra_fast" | "fast_fashion" | "premium" | "maison";
type ScanType = "barcode" | "label" | "manual" | "search";
type ReportReason = "wrong_composition" | "wrong_price" | "wrong_brand" | "duplicate" | "other";
type ReportStatus = "pending" | "confirmed" | "rejected";
type DuplicateStatus = "pending" | "confirmed_duplicate" | "not_duplicate";
type AuditAction = "insert" | "update" | "delete";
type PriceSource = "user" | "scraper" | "affiliate_feed";
type Gender = "uomo" | "donna" | "unisex";

interface Brand {
    id: string;
    name: string;
    slug: string;
    logo_url: string | null;
    description: string | null;
    origin_country: string | null;
    market_segment: MarketSegment;
    avg_worthy_score: number;
    product_count: number;
    total_scans: number;
    created_at: string;
}
interface BrandWithStats extends Brand {
    top_category: string | null;
    best_product_name: string | null;
    worst_product_name: string | null;
}

interface Category {
    id: string;
    name: string;
    slug: string;
    icon: string;
    avg_price: number;
    avg_composition_score: number;
    product_count: number;
}

interface MattiaReview {
    id: string;
    product_id: string;
    video_url: string;
    video_thumbnail_url: string | null;
    score_adjustment: number;
    review_text: string | null;
    published_at: string;
}
interface ReviewInsert {
    product_id: string;
    video_url: string;
    video_thumbnail_url?: string | null;
    score_adjustment: number;
    review_text?: string | null;
}

interface Composition {
    fiber: string;
    percentage: number;
}
interface Product {
    id: string;
    ean_barcode: string | null;
    brand_id: string;
    category_id: string;
    name: string;
    slug: string;
    gender: Gender;
    price: number;
    composition: Composition[];
    country_of_production: string | null;
    care_instructions: string | null;
    photo_urls: string[];
    label_photo_url: string | null;
    worthy_score: number;
    score_composition: number;
    score_qpr: number;
    score_fit: number | null;
    score_durability: number | null;
    verdict: Verdict;
    community_score: number | null;
    community_votes_count: number;
    verification_status: VerificationStatus;
    scan_count: number;
    contributed_by: string | null;
    affiliate_url: string | null;
    is_active: boolean;
    created_at: string;
    updated_at: string;
}
interface ProductInsert {
    ean_barcode?: string | null;
    brand_id: string;
    category_id: string;
    name: string;
    slug: string;
    gender?: Gender;
    price: number;
    composition: Composition[];
    country_of_production?: string | null;
    care_instructions?: string | null;
    photo_urls?: string[];
    label_photo_url?: string | null;
    contributed_by?: string | null;
    affiliate_url?: string | null;
}
interface ProductUpdate {
    ean_barcode?: string | null;
    brand_id?: string;
    category_id?: string;
    name?: string;
    gender?: Gender;
    price?: number;
    composition?: Composition[];
    country_of_production?: string | null;
    care_instructions?: string | null;
    photo_urls?: string[];
    label_photo_url?: string | null;
    worthy_score?: number;
    score_composition?: number;
    score_qpr?: number;
    score_fit?: number | null;
    score_durability?: number | null;
    verdict?: Verdict;
    community_score?: number | null;
    community_votes_count?: number;
    verification_status?: VerificationStatus;
    scan_count?: number;
    affiliate_url?: string | null;
    is_active?: boolean;
}
interface ProductWithRelations extends Product {
    brand: Brand;
    category: Category;
    mattia_review: MattiaReview | null;
}

interface User {
    id: string;
    email: string;
    display_name: string | null;
    avatar_url: string | null;
    points: number;
    trust_level: TrustLevel;
    role: UserRole;
    products_contributed: number;
    products_verified: number;
    error_rate: number;
    streak_days: number;
    last_active_date: string | null;
    is_premium: boolean;
    premium_expires_at: string | null;
    onboarding_completed: boolean;
    created_at: string;
    updated_at: string;
}
interface UserBrandPreference {
    id: string;
    user_id: string;
    brand_id: string;
    created_at: string;
}
interface UserCategoryPreference {
    id: string;
    user_id: string;
    category_id: string;
    created_at: string;
}
/**
 * Profilo pubblico di un utente (vista user_public_profiles).
 * Espone solo campi non sensibili — usare per leaderboard, profili pubblici, ecc.
 * trust_level e is_premium rimossi per sicurezza (migration 20260417000005).
 */
interface UserPublicProfile extends Pick<User, "id" | "display_name" | "avatar_url" | "points" | "products_contributed" | "products_verified" | "streak_days" | "created_at"> {
}
/**
 * @deprecated Usare UserPublicProfile per profili di altri utenti.
 * Mantenuto per compatibilita — trust_level e is_premium rimossi
 * dalla vista pubblica e non piu disponibili per altri utenti.
 */
interface UserProfile extends Pick<User, "id" | "display_name" | "avatar_url" | "points" | "products_contributed" | "streak_days"> {
}

interface ProductVote {
    id: string;
    product_id: string;
    user_id: string;
    score: number;
    fit_score: number | null;
    durability_score: number | null;
    comment: string | null;
    created_at: string;
}
interface VoteInsert {
    product_id: string;
    user_id: string;
    score: number;
    fit_score?: number | null;
    durability_score?: number | null;
    comment?: string | null;
}

interface ProductReport {
    id: string;
    product_id: string;
    user_id: string;
    reason: ReportReason;
    description: string | null;
    status: ReportStatus;
    created_at: string;
}

interface Badge {
    id: string;
    name: string;
    description: string;
    icon: string;
    points_required: number;
    benefit: string;
}
interface UserBadge {
    user_id: string;
    badge_id: string;
    earned_at: string;
}

interface ScanHistoryEntry {
    id: string;
    user_id: string;
    product_id: string | null;
    barcode: string;
    scan_type: ScanType;
    found: boolean;
    created_at: string;
}

interface DailyWorthy {
    id: string;
    product_id: string;
    featured_date: string;
    editorial_note: string | null;
    position: number;
    created_at: string;
}

interface UserConsent {
    user_id: string;
    tos_accepted: boolean;
    tos_accepted_at: string | null;
    tos_version: string | null;
    push_notifications: boolean;
    push_consent_at: string | null;
    analytics_consent: boolean;
    analytics_consent_at: string | null;
    updated_at: string;
}

interface ProductDuplicate {
    id: string;
    product_id: string;
    duplicate_of: string;
    similarity_score: number;
    status: DuplicateStatus;
    resolved_by: string | null;
    created_at: string;
    resolved_at: string | null;
}

interface AuditLogEntry {
    id: string;
    table_name: string;
    record_id: string;
    action: AuditAction;
    user_id: string | null;
    old_data: Record<string, unknown> | null;
    new_data: Record<string, unknown> | null;
    ip_address: string | null;
    created_at: string;
}

interface ScoreBreakdown {
    composition: number;
    qpr: number;
}
interface WorthyScoreResult {
    score: number;
    verdict: Verdict;
    breakdown: ScoreBreakdown;
}
type WorthyScoreLensName = "composition" | "manufacturing" | "qpr" | "sustainability";
interface LensResult {
    score: number | null;
    used: boolean;
}
declare const WORTHY_SCORE_V2_WEIGHTS: {
    readonly composition: 0.5;
    readonly manufacturing: 0.25;
    readonly qpr: 0.2;
    readonly sustainability: 0.05;
};
interface ScoreBreakdownV2 {
    version: "v2.0";
    lenses: Record<WorthyScoreLensName, LensResult>;
    weights: typeof WORTHY_SCORE_V2_WEIGHTS;
    confidence: number;
    raw: number;
    final: number;
    verdict: Verdict;
}
interface WorthyScoreV2Input {
    composition: {
        fiber: string;
        percentage: number;
    }[];
    price: number;
    category: {
        avgCompositionScore: number;
        avgPrice: number;
    };
    manufacturing?: {
        productionCountry?: string | null;
        weavingCountry?: string | null;
        spinningCountry?: string | null;
        dyeingCountry?: string | null;
    };
    productCertifications?: string[];
    brandCertifications?: string[];
}
interface WorthyScoreV2Result {
    score: number;
    verdict: Verdict;
    confidence: number;
    breakdown: ScoreBreakdownV2;
}

interface PriceHistory {
    id: string;
    product_id: string;
    price: number;
    recorded_at: string;
    source: PriceSource;
}

interface SavedProduct {
    id: string;
    user_id: string;
    product_id: string;
    created_at: string;
}
interface SavedComparison {
    id: string;
    user_id: string;
    product_ids: string[];
    title: string;
    created_at: string;
}

declare const FIBER_SCORES: Record<string, number>;
declare const ELASTANE_FIBERS: string[];
declare const ELASTANE_IGNORE_THRESHOLD = 5;
declare const ELASTANE_LOW_THRESHOLD = 10;
declare const ELASTANE_SCORE_LOW = 40;
declare const ELASTANE_SCORE_HIGH = 20;
declare const DEFAULT_FIBER_SCORE = 50;
declare function isElastane(fiber: string): boolean;
declare function elastaneScore(percentage: number): number | null;

declare function calculateCompositionScore(composition: Composition[]): number;

declare function calculateQPR(compScore: number, price: number, refScore: number, refPrice: number): number;

interface WorthyScoreInput {
    compositionScore: number;
    qprScore: number;
}
declare function calculateWorthyScore(params: WorthyScoreInput): WorthyScoreResult;

declare function verdictFromScore(score: number): Verdict;

declare function calculateWorthyScoreV2(input: WorthyScoreV2Input): WorthyScoreV2Result;

declare function compositionLens(composition: Composition[]): number;

declare function qprLens(compositionScore: number, price: number, refCompositionScore: number, refPrice: number): number;

interface ManufacturingInput {
    productionCountry?: string | null;
    weavingCountry?: string | null;
    spinningCountry?: string | null;
    dyeingCountry?: string | null;
    hasMadeInItaly100?: boolean;
}
declare function manufacturingLens(input: ManufacturingInput): number | null;

interface SustainabilityLensInput {
    productCertifications: string[];
    brandCertifications: string[];
}
declare function sustainabilityLens(input: SustainabilityLensInput): number | null;

declare const FIBERS: readonly [{
    readonly id: "cashmere";
    readonly nameIT: "Cashmere";
    readonly score: 98;
    readonly tier: "premium";
}, {
    readonly id: "silk";
    readonly nameIT: "Seta";
    readonly score: 95;
    readonly tier: "premium";
}, {
    readonly id: "merino_wool";
    readonly nameIT: "Lana Merino";
    readonly score: 92;
    readonly tier: "premium";
}, {
    readonly id: "supima_cotton";
    readonly nameIT: "Cotone Supima";
    readonly score: 90;
    readonly tier: "premium";
}, {
    readonly id: "pima_cotton";
    readonly nameIT: "Cotone Pima";
    readonly score: 90;
    readonly tier: "premium";
}, {
    readonly id: "egyptian_cotton";
    readonly nameIT: "Cotone Egiziano";
    readonly score: 90;
    readonly tier: "premium";
}, {
    readonly id: "linen";
    readonly nameIT: "Lino";
    readonly score: 88;
    readonly tier: "alto";
}, {
    readonly id: "organic_cotton";
    readonly nameIT: "Cotone Biologico";
    readonly score: 85;
    readonly tier: "alto";
}, {
    readonly id: "lyocell";
    readonly nameIT: "Lyocell";
    readonly score: 82;
    readonly tier: "alto";
}, {
    readonly id: "tencel";
    readonly nameIT: "Tencel";
    readonly score: 82;
    readonly tier: "alto";
}, {
    readonly id: "wool";
    readonly nameIT: "Lana";
    readonly score: 78;
    readonly tier: "alto";
}, {
    readonly id: "cotton";
    readonly nameIT: "Cotone";
    readonly score: 72;
    readonly tier: "medio_alto";
}, {
    readonly id: "modal";
    readonly nameIT: "Modal";
    readonly score: 68;
    readonly tier: "medio_alto";
}, {
    readonly id: "cupro";
    readonly nameIT: "Cupro";
    readonly score: 65;
    readonly tier: "medio_alto";
}, {
    readonly id: "viscose";
    readonly nameIT: "Viscosa";
    readonly score: 52;
    readonly tier: "medio";
}, {
    readonly id: "rayon";
    readonly nameIT: "Rayon";
    readonly score: 52;
    readonly tier: "medio";
}, {
    readonly id: "nylon";
    readonly nameIT: "Nylon";
    readonly score: 45;
    readonly tier: "medio";
}, {
    readonly id: "polyamide";
    readonly nameIT: "Poliammide";
    readonly score: 45;
    readonly tier: "medio";
}, {
    readonly id: "recycled_polyester";
    readonly nameIT: "Poliestere Riciclato";
    readonly score: 42;
    readonly tier: "medio_basso";
}, {
    readonly id: "polyester";
    readonly nameIT: "Poliestere";
    readonly score: 25;
    readonly tier: "basso";
}, {
    readonly id: "acrylic";
    readonly nameIT: "Acrilico";
    readonly score: 15;
    readonly tier: "basso";
}, {
    readonly id: "elastane";
    readonly nameIT: "Elastan";
    readonly score: 0;
    readonly tier: "neutro";
}, {
    readonly id: "spandex";
    readonly nameIT: "Spandex";
    readonly score: 0;
    readonly tier: "neutro";
}];
type FiberId = (typeof FIBERS)[number]["id"];
type FiberTier = (typeof FIBERS)[number]["tier"];

declare const BADGES: readonly [{
    readonly id: "fashion_scout";
    readonly name: "Fashion Scout";
    readonly description: "Hai iniziato a contribuire!";
    readonly icon: "🔍";
    readonly pointsRequired: 50;
    readonly benefit: "Badge visibile sul profilo";
}, {
    readonly id: "style_expert";
    readonly name: "Style Expert";
    readonly description: "Contributor esperto";
    readonly icon: "⭐";
    readonly pointsRequired: 200;
    readonly benefit: "Accesso anticipato nuove review";
}, {
    readonly id: "database_hero";
    readonly name: "Database Hero";
    readonly description: "Il database ti ringrazia";
    readonly icon: "🏆";
    readonly pointsRequired: 500;
    readonly benefit: "Prodotti senza revisione";
}, {
    readonly id: "worthy_legend";
    readonly name: "Worthy Legend";
    readonly description: "Leggenda della community";
    readonly icon: "👑";
    readonly pointsRequired: 1000;
    readonly benefit: "Menzione stories Mattia";
}, {
    readonly id: "top_contributor";
    readonly name: "Top Contributor";
    readonly description: "Top 10 del mese";
    readonly icon: "🥇";
    readonly pointsRequired: 0;
    readonly benefit: "Badge esclusivo + shoutout";
}];
type BadgeId = (typeof BADGES)[number]["id"];

declare const CATEGORIES: readonly [{
    readonly slug: "t-shirt";
    readonly name: "T-Shirt";
    readonly icon: "👕";
}, {
    readonly slug: "felpe";
    readonly name: "Felpe";
    readonly icon: "🧥";
}, {
    readonly slug: "jeans";
    readonly name: "Jeans";
    readonly icon: "👖";
}, {
    readonly slug: "pantaloni";
    readonly name: "Pantaloni";
    readonly icon: "👖";
}, {
    readonly slug: "giacche";
    readonly name: "Giacche";
    readonly icon: "🧥";
}, {
    readonly slug: "sneakers";
    readonly name: "Sneakers";
    readonly icon: "👟";
}, {
    readonly slug: "camicie";
    readonly name: "Camicie";
    readonly icon: "👔";
}, {
    readonly slug: "intimo";
    readonly name: "Intimo";
    readonly icon: "𞩲";
}, {
    readonly slug: "accessori";
    readonly name: "Accessori";
    readonly icon: "🧣";
}, {
    readonly slug: "t-shirt-basic";
    readonly name: "T-shirt basic";
    readonly icon: "👕";
}, {
    readonly slug: "t-shirt-oversize";
    readonly name: "T-shirt oversize";
    readonly icon: "👕";
}, {
    readonly slug: "polo";
    readonly name: "Polo";
    readonly icon: "👕";
}, {
    readonly slug: "canotta";
    readonly name: "Canotte";
    readonly icon: "🩱";
}, {
    readonly slug: "top-sportivo";
    readonly name: "Top sportivi";
    readonly icon: "💪";
}, {
    readonly slug: "camicia";
    readonly name: "Camicie";
    readonly icon: "👔";
}, {
    readonly slug: "felpa-cappuccio";
    readonly name: "Felpe con cappuccio";
    readonly icon: "🧥";
}, {
    readonly slug: "felpa-girocollo";
    readonly name: "Felpe girocollo";
    readonly icon: "🧥";
}, {
    readonly slug: "maglione";
    readonly name: "Maglioni";
    readonly icon: "🧶";
}, {
    readonly slug: "cardigan";
    readonly name: "Cardigan";
    readonly icon: "🧶";
}, {
    readonly slug: "bomber";
    readonly name: "Bomber";
    readonly icon: "🧥";
}, {
    readonly slug: "parka";
    readonly name: "Parka";
    readonly icon: "🧥";
}, {
    readonly slug: "blazer";
    readonly name: "Blazer";
    readonly icon: "🧥";
}, {
    readonly slug: "piumino";
    readonly name: "Piumini";
    readonly icon: "🧥";
}, {
    readonly slug: "giubbotto";
    readonly name: "Giubbotti";
    readonly icon: "🧥";
}, {
    readonly slug: "chinos";
    readonly name: "Chinos";
    readonly icon: "👖";
}, {
    readonly slug: "cargo";
    readonly name: "Cargo";
    readonly icon: "👖";
}, {
    readonly slug: "jogger";
    readonly name: "Jogger";
    readonly icon: "👖";
}, {
    readonly slug: "pantaloni-eleganti";
    readonly name: "Pantaloni eleganti";
    readonly icon: "👖";
}, {
    readonly slug: "jeans-slim";
    readonly name: "Jeans slim";
    readonly icon: "👖";
}, {
    readonly slug: "jeans-regular";
    readonly name: "Jeans regular";
    readonly icon: "👖";
}, {
    readonly slug: "jeans-wide";
    readonly name: "Jeans wide leg";
    readonly icon: "👖";
}, {
    readonly slug: "shorts";
    readonly name: "Shorts";
    readonly icon: "🩳";
}, {
    readonly slug: "shorts-sportivi";
    readonly name: "Shorts sportivi";
    readonly icon: "🩳";
}, {
    readonly slug: "calzini";
    readonly name: "Calzini";
    readonly icon: "🧦";
}, {
    readonly slug: "scarpe-eleganti";
    readonly name: "Scarpe eleganti";
    readonly icon: "👞";
}, {
    readonly slug: "cappelli";
    readonly name: "Cappelli";
    readonly icon: "🧢";
}, {
    readonly slug: "sciarpe";
    readonly name: "Sciarpe";
    readonly icon: "🧣";
}, {
    readonly slug: "cinture";
    readonly name: "Cinture";
    readonly icon: "👔";
}, {
    readonly slug: "borse";
    readonly name: "Borse";
    readonly icon: "👜";
}, {
    readonly slug: "costume";
    readonly name: "Costumi";
    readonly icon: "🩱";
}, {
    readonly slug: "leggings";
    readonly name: "Leggings";
    readonly icon: "🦵";
}, {
    readonly slug: "tuta";
    readonly name: "Tute sportive";
    readonly icon: "🏃";
}];
type CategorySlug = (typeof CATEGORIES)[number]["slug"];

declare const LAUNCH_BRANDS: readonly [{
    readonly name: "Zara";
    readonly slug: "zara";
    readonly originCountry: "Spagna";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "H&M";
    readonly slug: "h-and-m";
    readonly originCountry: "Svezia";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Uniqlo";
    readonly slug: "uniqlo";
    readonly originCountry: "Giappone";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Shein";
    readonly slug: "shein";
    readonly originCountry: "Cina";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Bershka";
    readonly slug: "bershka";
    readonly originCountry: "Spagna";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Pull&Bear";
    readonly slug: "pull-and-bear";
    readonly originCountry: "Spagna";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Stradivarius";
    readonly slug: "stradivarius";
    readonly originCountry: "Spagna";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Primark";
    readonly slug: "primark";
    readonly originCountry: "Irlanda";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "ASOS";
    readonly slug: "asos";
    readonly originCountry: "UK";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Mango";
    readonly slug: "mango";
    readonly originCountry: "Spagna";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "COS";
    readonly slug: "cos";
    readonly originCountry: "Svezia";
    readonly marketSegment: MarketSegment;
}, {
    readonly name: "Massimo Dutti";
    readonly slug: "massimo-dutti";
    readonly originCountry: "Spagna";
    readonly marketSegment: MarketSegment;
}];

declare const VERDICTS: {
    readonly steal: {
        readonly min: 86;
        readonly max: 100;
        readonly label: "Steal";
        readonly emoji: "🔥";
        readonly description: "Affare incredibile";
    };
    readonly worthy: {
        readonly min: 71;
        readonly max: 85;
        readonly label: "Worthy";
        readonly emoji: "✅";
        readonly description: "Vale il prezzo";
    };
    readonly fair: {
        readonly min: 51;
        readonly max: 70;
        readonly label: "Fair";
        readonly emoji: "😐";
        readonly description: "Nella media";
    };
    readonly meh: {
        readonly min: 31;
        readonly max: 50;
        readonly label: "Meh";
        readonly emoji: "👎";
        readonly description: "Sotto la media";
    };
    readonly not_worthy: {
        readonly min: 0;
        readonly max: 30;
        readonly label: "Not Worthy";
        readonly emoji: "🚩";
        readonly description: "Non vale il prezzo";
    };
};

declare const POINTS: {
    readonly scan_existing: 2;
    readonly contribute_product: 15;
    readonly confirm_data: 5;
    readonly report_confirmed: 10;
    readonly first_scan_of_day: 3;
    readonly streak_7_days: 25;
    readonly referral: 20;
};
declare const RATE_LIMITS: {
    readonly products_per_day: 20;
    readonly scans_per_hour: 60;
    readonly votes_per_hour: 30;
    readonly reports_per_day: 10;
    readonly label_scans_per_hour: 15;
};
declare const VALIDATION: {
    readonly product_name_min: 3;
    readonly product_name_max: 200;
    readonly price_min: 0.01;
    readonly price_max: 500;
    readonly composition_fibers_min: 1;
    readonly composition_fibers_max: 8;
    readonly composition_sum_target: 100;
    readonly composition_sum_tolerance: 1;
    readonly vote_score_min: 1;
    readonly vote_score_max: 10;
};

declare const MARKET_SEGMENTS: readonly [{
    readonly id: MarketSegment;
    readonly label: "Ultra Fast Fashion";
}, {
    readonly id: MarketSegment;
    readonly label: "Fast Fashion";
}, {
    readonly id: MarketSegment;
    readonly label: "Premium";
}, {
    readonly id: MarketSegment;
    readonly label: "Maison";
}];

declare const NAV_TABS: readonly ["search", "top-rated", "scan", "coach", "saved"];
type NavTab = (typeof NAV_TABS)[number];
declare const ONBOARDING_STEPS: readonly ["welcome", "value_prop_1", "value_prop_2", "brand_selection", "category_selection", "notifications", "complete"];
type OnboardingStep = (typeof ONBOARDING_STEPS)[number];

declare const FIBER_DESCRIPTIONS: Record<string, string>;
declare function getElastaneDescription(percentage: number): string;
declare function getFiberDescription(fiber: string, percentage: number): string | null;

interface Country {
    iso2: string;
    name_it: string;
    region: "EU" | "Asia" | "Americas" | "Africa" | "Oceania";
    manufacturing_tier: 1 | 2 | 3 | 4;
    manufacturing_score: number;
}
declare const COUNTRIES: Record<string, Country>;
type CountryIso2 = keyof typeof COUNTRIES;
declare function getCountry(iso2: string | null | undefined): Country | undefined;
declare function manufacturingScoreFor(iso2: string | null | undefined): number | null;

type CertificationScope = "fiber" | "process" | "brand" | "product" | "manufacturing";
interface Certification {
    id: string;
    display_name: string;
    scope: CertificationScope;
    bonus_points: number;
}
declare const CERTIFICATIONS: Record<string, Certification>;
type CertificationId = keyof typeof CERTIFICATIONS;
declare function getCertification(id: string | null | undefined): Certification | undefined;
declare function bonusFor(id: string | null | undefined): number;

declare function validateProduct(data: Partial<ProductInsert>): {
    valid: boolean;
    errors: string[];
};

declare function validateComposition(fibers: Composition[]): {
    valid: boolean;
    errors: string[];
};

declare function validatePrice(price: number, composition?: Composition[]): {
    valid: boolean;
    plausible: boolean;
    warning?: string;
};

declare function isValidEAN13(code: string): boolean;
declare function isValidUPC(code: string): boolean;
declare function isValidBarcode(code: string): boolean;

export { type AuditAction, type AuditLogEntry, BADGES, type Badge, type BadgeId, type Brand, type BrandWithStats, CATEGORIES, CERTIFICATIONS, COUNTRIES, type Category, type CategorySlug, type Certification, type CertificationId, type CertificationScope, type Composition, type Country, type CountryIso2, DEFAULT_FIBER_SCORE, type DailyWorthy, type DuplicateStatus, ELASTANE_FIBERS, ELASTANE_IGNORE_THRESHOLD, ELASTANE_LOW_THRESHOLD, ELASTANE_SCORE_HIGH, ELASTANE_SCORE_LOW, FIBERS, FIBER_DESCRIPTIONS, FIBER_SCORES, type FiberId, type FiberTier, type Gender, LAUNCH_BRANDS, type LensResult, MARKET_SEGMENTS, type ManufacturingInput, type MarketSegment, type MattiaReview, NAV_TABS, type NavTab, ONBOARDING_STEPS, type OnboardingStep, POINTS, type PriceHistory, type PriceSource, type Product, type ProductDuplicate, type ProductInsert, type ProductReport, type ProductUpdate, type ProductVote, type ProductWithRelations, RATE_LIMITS, type ReportReason, type ReportStatus, type ReviewInsert, type SavedComparison, type SavedProduct, type ScanHistoryEntry, type ScanType, type ScoreBreakdown, type ScoreBreakdownV2, type SustainabilityLensInput, type TrustLevel, type User, type UserBadge, type UserBrandPreference, type UserCategoryPreference, type UserConsent, type UserProfile, type UserPublicProfile, type UserRole, VALIDATION, VERDICTS, type Verdict, type VerificationStatus, type VoteInsert, type WorthyScoreInput, type WorthyScoreLensName, type WorthyScoreResult, type WorthyScoreV2Input, type WorthyScoreV2Result, bonusFor, calculateCompositionScore, calculateQPR, calculateWorthyScore, calculateWorthyScoreV2, compositionLens, elastaneScore, getCertification, getCountry, getElastaneDescription, getFiberDescription, isElastane, isValidBarcode, isValidEAN13, isValidUPC, manufacturingLens, manufacturingScoreFor, qprLens, sustainabilityLens, validateComposition, validatePrice, validateProduct, verdictFromScore };
