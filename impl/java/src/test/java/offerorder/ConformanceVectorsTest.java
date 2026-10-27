package offerorder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.TestFactory;

/**
 * Option 1, the test oracle: fixed requests whose answers the Lean model
 * computed.  {@code lake exe oracle --vectors} writes them to
 * build/oracle/vectors.jsonl; each one becomes a test that the Java code must
 * answer the same way.
 */
class ConformanceVectorsTest {

  static Path vectorsFile() {
    return Oracle.repoRoot().toPath().resolve("build/oracle/vectors.jsonl");
  }

  @TestFactory
  Stream<DynamicTest> javaAnswersEveryVectorAsTheModelDoes() throws IOException {
    Path file = vectorsFile();
    assertTrue(Files.exists(file), file + " is missing; run: lake exe oracle --vectors > " + file);
    List<String> lines = Files.readAllLines(file).stream().filter(l -> !l.isBlank()).toList();
    assertTrue(lines.size() > 0, "no vectors in " + file);
    return lines.stream().map(line -> {
      JsonNode v = read(line);
      return DynamicTest.dynamicTest(v.get("name").asText(), () ->
          assertEquals(v.get("response"), ModelJson.respond(v.get("request")),
              "request: " + v.get("request")));
    });
  }

  private static JsonNode read(String line) {
    try {
      return ModelJson.MAPPER.readTree(line);
    } catch (IOException e) {
      throw new IllegalStateException(e);
    }
  }
}
