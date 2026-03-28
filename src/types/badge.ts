export interface Badge {
  id: string;
  name: string;
  description: string;
  icon: string;
  points_required: number;
  benefit: string;
}

export interface UserBadge {
  user_id: string;
  badge_id: string;
  earned_at: string;
}
