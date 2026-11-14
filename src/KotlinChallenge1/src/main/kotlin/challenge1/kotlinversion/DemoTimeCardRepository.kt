package challenge1.kotlinversion

import org.springframework.data.repository.CrudRepository

interface DemoTimeCardRepository : CrudRepository<DemoTimeCard, Long>
