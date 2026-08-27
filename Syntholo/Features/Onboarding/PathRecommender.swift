enum PathRecommender {
    static func recommend(goal: LearnerGoal, experience _: ExperienceLevel) -> LearningPath {
        switch goal {
        case .studySmarter:
            .school
        case .workProductivity:
            .work
        case .createContent:
            .creation
        case .buildWithAI:
            .build
        }
    }
}
