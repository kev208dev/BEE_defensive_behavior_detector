import unittest

import numpy as np

from verify_tflite import decode_predictions


class DecodePredictionsTest(unittest.TestCase):
    def test_decodes_both_vespai_classes_and_suppresses_overlap(self) -> None:
        predictions = np.array(
            [
                [0.25, 0.25, 0.10, 0.10, 0.90, 1.00, 0.00],
                [0.75, 0.75, 0.10, 0.10, 0.95, 0.00, 0.90],
                [0.76, 0.76, 0.10, 0.10, 0.90, 0.00, 0.90],
                [0.50, 0.50, 0.10, 0.10, 0.79, 1.00, 0.00],
            ],
            dtype=np.float32,
        )

        detections = decode_predictions(
            predictions,
            frame_width=640,
            frame_height=640,
            input_width=640,
            input_height=640,
            confidence_threshold=0.8,
            iou_threshold=0.45,
        )

        self.assertEqual(
            [item["class_name"] for item in detections],
            ["Vespa crabro", "Vespa velutina"],
        )
        self.assertAlmostEqual(detections[0]["confidence"], 0.9, places=5)
        self.assertAlmostEqual(detections[1]["confidence"], 0.855, places=5)

    def test_reverses_letterbox_padding(self) -> None:
        predictions = np.array(
            [[0.5, 0.5, 0.5, 0.28125, 0.9, 1.0, 0.0]],
            dtype=np.float32,
        )

        detection = decode_predictions(
            predictions,
            frame_width=1920,
            frame_height=1080,
            input_width=640,
            input_height=640,
            confidence_threshold=0.8,
            iou_threshold=0.45,
        )[0]

        self.assertAlmostEqual(detection["x"], 0.25)
        self.assertAlmostEqual(detection["y"], 0.25)
        self.assertAlmostEqual(detection["width"], 0.5)
        self.assertAlmostEqual(detection["height"], 0.5)


if __name__ == "__main__":
    unittest.main()
