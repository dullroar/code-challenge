package challenge1.kotlinversion

import java.awt.Color
import java.nio.file.Files
import java.nio.file.Path
import java.time.LocalDate
import java.time.temporal.IsoFields
import java.util.Random
import java.util.concurrent.ThreadLocalRandom
import java.util.concurrent.locks.ReentrantLock
import javax.swing.JDialog
import javax.swing.JLabel
import javax.swing.Timer
import org.springframework.boot.WebApplicationType
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.builder.SpringApplicationBuilder
import org.springframework.context.support.GenericXmlApplicationContext
import org.springframework.core.io.ByteArrayResource
import org.springframework.data.repository.CrudRepository
import org.springframework.util.ReflectionUtils

// A Kotlin + Spring port of Jim Lehmer's 2008 C# 3.0 challenge, following the 2026 .NET
// modernization at https://github.com/dullroar/code-challenge. It sits beside the Java port
// in challenge1.javaversion so the two languages can be compared line for line.
//
// The objective remains: make a small desktop program using exactly one statement - a
// for statement whose body is empty. The point is comparison, not production style.
//
// Kotlin has no three-part for statement and needs no semicolons, so the three sections
// become the three parts of a generated sequence: the seed is the initializer, takeIf is the
// condition, and the also chain is the update. The loop body runs once before the first
// condition check, where C# and Java check first. The body is empty, so nothing differs.
//
// The program only writes clearly identified *demo* time cards into a SQLite database
// in the project's data directory. It is not connected to, and must not be used for, a real
// time-reporting system.
@SpringBootApplication
class Program

fun main(args: Array<String>) {
    for // Still the only statement.
    (
        @Suppress("unused") pass in generateSequence(
            // The object expression is the iterator-state wrapper, as the anonymous object was
            // in C#. Kotlin keeps its anonymous type through the sequence, so its properties
            // stay reachable.
            object {
                // The XML fragment is still deliberately gratuitous. It becomes part of the
                // Spring bean definitions below, as the XElement became part of the XAML.
                val xmlAnim = """
                    <bean id="anim" class="javax.swing.Timer" init-method="start">
                      <constructor-arg value="40"/>
                      <constructor-arg><null/></constructor-arg>
                    </bean>
                    """
                val totalHours = mutableListOf<Double>()
                val user: String = System.getProperty("user.name")
                val directory: Path = Files.createDirectories(Path.of("data"))
                val ctx = SpringApplicationBuilder(Program::class.java)
                    .web(WebApplicationType.NONE)
                    .headless(false)
                    .properties("spring.datasource.url=jdbc:sqlite:${directory.resolve("demo-timecards.db")}")
                    .run(*args)
                val timeCards = ctx.getBean(DemoTimeCardRepository::class.java)
                val pending = mutableListOf<DemoTimeCard>()
                val rnd: Random = ThreadLocalRandom.current()
                val categories = listOf("Meetings", "Coding", "Debugging", "Learning").iterator()
                val mutex = ReentrantLock()
            }
                //   *
                //  *
        ) { i -> i  // **************** FIRST BOUNDARY (the first semicolon) ****************
                //  *
                //   *
            // sum() stands in for LINQ to Objects. When the demo batch reaches approximately
            // one work week, show the result and terminate the loop.
            .takeIf {
                if (i.totalHours.sum() <= 40.0 && i.categories.hasNext())
                    true
                else
                    GenericXmlApplicationContext(
                        ByteArrayResource(
                            """
                            <beans xmlns="http://www.springframework.org/schema/beans"
                                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                   xsi:schemaLocation="http://www.springframework.org/schema/beans
                                       https://www.springframework.org/schema/beans/spring-beans.xsd">
                              <bean id="banner" class="javax.swing.JLabel">
                                <property name="text" value="DEMO ONLY - no real time system is involved"/>
                                <property name="horizontalAlignment" value="0"/>
                                <property name="foreground" value="#{T(java.awt.Color).decode('#FFCE56')}"/>
                                <property name="font" value="#{new java.awt.Font('SansSerif', 1, 18)}"/>
                              </bean>
                              <bean id="total" class="javax.swing.JLabel">
                                <property name="text" value="Total simulated hours: ${"%.1f".format(i.totalHours.sum())}"/>
                                <property name="horizontalAlignment" value="0"/>
                                <property name="foreground" value="#{T(java.awt.Color).WHITE}"/>
                                <property name="font" value="#{new java.awt.Font('SansSerif', 1, 24)}"/>
                              </bean>
                              <bean id="saved" class="javax.swing.JLabel">
                                <property name="text" value="Saved locally for the modernization exercise."/>
                                <property name="horizontalAlignment" value="0"/>
                                <property name="foreground" value="#{T(java.awt.Color).WHITE}"/>
                                <property name="font" value="#{new java.awt.Font('SansSerif', 1, 18)}"/>
                              </bean>
                              <bean id="panel" class="javax.swing.JPanel">
                                <constructor-arg value="#{new java.awt.BorderLayout()}"/>
                                <property name="background" value="#{T(java.awt.Color).decode('#172033')}"/>
                                <property name="border"
                                          value="#{T(javax.swing.BorderFactory).createEmptyBorder(24, 28, 40, 28)}"/>
                              </bean>
                              <bean class="org.springframework.beans.factory.config.MethodInvokingBean">
                                <property name="targetObject" ref="panel"/>
                                <property name="targetMethod" value="add"/>
                                <property name="arguments"><list><ref bean="banner"/><value>North</value></list></property>
                              </bean>
                              <bean class="org.springframework.beans.factory.config.MethodInvokingBean">
                                <property name="targetObject" ref="panel"/>
                                <property name="targetMethod" value="add"/>
                                <property name="arguments"><list><ref bean="total"/><value>Center</value></list></property>
                              </bean>
                              <bean class="org.springframework.beans.factory.config.MethodInvokingBean">
                                <property name="targetObject" ref="panel"/>
                                <property name="targetMethod" value="add"/>
                                <property name="arguments"><list><ref bean="saved"/><value>South</value></list></property>
                              </bean>
                              <bean id="window" class="javax.swing.JDialog">
                                <constructor-arg type="java.awt.Window"><null/></constructor-arg>
                                <property name="title" value="Only One STATEMENT (Kotlin + Spring demo)"/>
                                <property name="modal" value="true"/>
                                <property name="size" value="#{new java.awt.Dimension(520, 320)}"/>
                                <property name="resizable" value="false"/>
                                <property name="defaultCloseOperation" value="2"/>
                                <property name="contentPane" ref="panel"/>
                              </bean>
                              ${i.xmlAnim}
                            </beans>""".trimIndent().toByteArray()))
                        // The pulse: every label fades from opaque to 45% and back, 1.2 seconds each way.
                        .also { xml ->
                            xml.getBean(Timer::class.java).addActionListener {
                                xml.getBeansOfType(JLabel::class.java).values.forEach { label ->
                                    label.foreground = Color(
                                        label.foreground.red,
                                        label.foreground.green,
                                        label.foreground.blue,
                                        (255 * (0.45 + 0.55 * Math.abs(System.nanoTime() / 1e9 % 2.4 / 1.2 - 1))).toInt())
                                }
                            }
                        }
                        .also { xml -> xml.getBean(JDialog::class.java).setLocationRelativeTo(null) }
                        // A modal dialog blocks here until it is closed, as Application.Run did.
                        .also { xml -> xml.getBean(JDialog::class.java).isVisible = true }
                        .also { xml -> xml.getBean(Timer::class.java).stop() }
                        .also { xml -> xml.close() }
                        .let { false }
            }
               //   *
               //  *
            // **************** LAST BOUNDARY (the last semicolon) ****************
               //  *
               //   *
            // The data access shape intentionally resembles Add/SaveChanges: the loop stages a
            // record and a background thread saves it. The lock keeps the save from overlapping
            // the next add.
            ?.also { i.mutex.lock() }
            ?.also { i.totalHours.add(i.rnd.nextInt(10, 20).toDouble()) }
            ?.also {
                i.pending.add(
                    DemoTimeCard(
                        category = i.categories.next(),
                        hours = i.totalHours.last(),
                        userId = i.user,
                        year = LocalDate.now().year,
                        week = LocalDate.now().get(IsoFields.WEEK_OF_WEEK_BASED_YEAR),
                        isDemo = true))
            }
            ?.also { i.mutex.unlock() }
            // The gratuitous background thread and reflection are retained as a historic contrast.
            ?.also {
                Thread {
                    StringBuilder(
                        "" +
                        ReflectionUtils.invokeMethod(
                            ReflectionUtils.findMethod(ReentrantLock::class.java, "lock")!!, i.mutex) +
                        ReflectionUtils.invokeMethod(
                            ReflectionUtils.findMethod(CrudRepository::class.java, "saveAll", Iterable::class.java)!!,
                            i.timeCards, i.pending) +
                        ReflectionUtils.invokeMethod(
                            ReflectionUtils.findMethod(ReentrantLock::class.java, "unlock")!!, i.mutex)).toString()
                }.start()
            }
        }
    )
    { /* Intentionally empty. */ }
}
