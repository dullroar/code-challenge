package challenge1.kotlinversion

import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table

@Entity
@Table(name = "time_cards")
class DemoTimeCard(
    var category: String,
    var hours: Double,
    var userId: String,
    var year: Int,
    var week: Int,
    var isDemo: Boolean,
    @field:Id
    @field:GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
)
